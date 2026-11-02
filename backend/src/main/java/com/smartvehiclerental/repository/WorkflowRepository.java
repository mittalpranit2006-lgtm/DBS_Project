package com.smartvehiclerental.repository;

import com.smartvehiclerental.http.ApiException;
import com.smartvehiclerental.http.Json;
import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** Member 3 rental workflow and Member 1 payment/report queries. */
public final class WorkflowRepository {
    private static Timestamp ts(LocalDateTime value) { return Timestamp.valueOf(value); }

    public Map<String,Object> dashboard(Connection c) throws SQLException {
        String sql="SELECT "
            +"(SELECT COUNT(*) FROM CUSTOMER) AS Customer_Count,"
            +"(SELECT COUNT(*) FROM VEHICLE) AS Vehicle_Count,"
            +"(SELECT COUNT(*) FROM RENTAL) AS Rental_Count,"
            +"(SELECT COUNT(*) FROM PAYMENT) AS Payment_Count,"
            +"(SELECT COUNT(*) FROM VEHICLE WHERE Availability_Status='Available') AS Available_Vehicles,"
            +"(SELECT COUNT(*) FROM RENTAL WHERE Status_Name='Active') AS Active_Rentals,"
            +"(SELECT COUNT(*) FROM RENTAL WHERE Status_Name='Active' "
            +"AND Expected_Return_Date<CAST(SYSTIMESTAMP AS TIMESTAMP)) AS Overdue_Rentals,"
            +"(SELECT NVL(SUM(Amount),0) FROM PAYMENT WHERE Payment_Status='Completed') AS Cash_Collected "
            +"FROM DUAL";
        try(PreparedStatement ps=c.prepareStatement(sql)) {
            ps.setQueryTimeout(10);
            try(ResultSet rs=ps.executeQuery()) {rs.next();return JdbcRows.map(rs);}
        }
    }

    public Map<String,Object> start(Connection c,long customer,long vehicle,long employee,
                                    LocalDateTime start,LocalDateTime expected) throws SQLException {
        try(CallableStatement call=c.prepareCall("{call SVR_WORKFLOW.START_RENTAL(?,?,?,?,?,?)}")){
            call.setLong(1,customer);call.setLong(2,vehicle);call.setLong(3,employee);
            call.setTimestamp(4,ts(start));call.setTimestamp(5,ts(expected));
            call.registerOutParameter(6,Types.NUMERIC);call.setQueryTimeout(15);call.execute();
            return rental(c,call.getLong(6));
        }
    }
    public Map<String,Object> recordReturn(Connection c,long id,LocalDateTime actual) throws SQLException {
        try(CallableStatement call=c.prepareCall("{call SVR_WORKFLOW.RECORD_RETURN(?,?,?)}")){
            call.setLong(1,id);call.setTimestamp(2,ts(actual));
            call.registerOutParameter(3,Types.NUMERIC);call.setQueryTimeout(15);call.execute();
            Map<String,Object> row=rental(c,id);row.put("finalAmount",call.getBigDecimal(3));return row;
        }
    }
    public Map<String,Object> recordPayment(Connection c,long rentalId,BigDecimal amount,String method,
                                             LocalDateTime paidAt) throws SQLException {
        try(CallableStatement call=c.prepareCall("{call SVR_WORKFLOW.RECORD_PAYMENT(?,?,?,?,?)}")){
            call.setLong(1,rentalId);call.setBigDecimal(2,amount);call.setString(3,method);
            call.setTimestamp(4,ts(paidAt));call.registerOutParameter(5,Types.NUMERIC);
            call.setQueryTimeout(15);call.execute();return payment(c,call.getLong(5));
        }
    }
    public BigDecimal charge(Connection c,LocalDateTime start,LocalDateTime end,BigDecimal rate) throws SQLException {
        try(CallableStatement call=c.prepareCall("{? = call SVR_WORKFLOW.CALCULATE_CHARGE(?,?,?)}")){
            call.registerOutParameter(1,Types.NUMERIC);call.setTimestamp(2,ts(start));
            call.setTimestamp(3,ts(end));call.setBigDecimal(4,rate);
            call.setQueryTimeout(10);call.execute();return call.getBigDecimal(1);
        }
    }
    public BigDecimal balance(Connection c,long rentalId) throws SQLException {
        try(CallableStatement call=c.prepareCall("{? = call SVR_WORKFLOW.OUTSTANDING_BALANCE(?)}")){
            call.registerOutParameter(1,Types.NUMERIC);call.setLong(2,rentalId);
            call.setQueryTimeout(10);call.execute();return call.getBigDecimal(1);
        }
    }

    public Map<String,Object> rental(Connection c,long id) throws SQLException {
        return one(c,"SELECT * FROM RENTAL WHERE Rental_ID=?",id);
    }
    public Map<String,Object> payment(Connection c,long id) throws SQLException {
        return one(c,"SELECT * FROM PAYMENT WHERE Payment_ID=?",id);
    }
    private Map<String,Object> one(Connection c,String sql,long id) throws SQLException {
        try(PreparedStatement ps=c.prepareStatement(sql)){
            ps.setLong(1,id);ps.setQueryTimeout(10);
            try(ResultSet rs=ps.executeQuery()){
                if(!rs.next())throw new ApiException(404,"not_found","Record not found.");
                return JdbcRows.map(rs);
            }
        }
    }
    public List<Map<String,Object>> rentals(Connection c,Long customer,Long vehicle,String status,int limit) throws SQLException {
        String sql="SELECT * FROM RENTAL WHERE (? IS NULL OR Customer_ID=?) AND (? IS NULL OR Vehicle_ID=?) "
            +"AND (? IS NULL OR Status_Name=?) ORDER BY Rental_ID FETCH FIRST ? ROWS ONLY";
        try(PreparedStatement ps=c.prepareStatement(sql)){
            if(customer==null){ps.setNull(1,Types.NUMERIC);ps.setNull(2,Types.NUMERIC);}else{ps.setLong(1,customer);ps.setLong(2,customer);}
            if(vehicle==null){ps.setNull(3,Types.NUMERIC);ps.setNull(4,Types.NUMERIC);}else{ps.setLong(3,vehicle);ps.setLong(4,vehicle);}
            ps.setString(5,status);ps.setString(6,status);ps.setInt(7,limit);ps.setQueryTimeout(10);
            return rows(ps);
        }
    }
    public List<Map<String,Object>> payments(Connection c,Long rentalId,int limit) throws SQLException {
        try(PreparedStatement ps=c.prepareStatement("SELECT * FROM PAYMENT WHERE (? IS NULL OR Rental_ID=?) ORDER BY Payment_ID FETCH FIRST ? ROWS ONLY")){
            if(rentalId==null){ps.setNull(1,Types.NUMERIC);ps.setNull(2,Types.NUMERIC);}else{ps.setLong(1,rentalId);ps.setLong(2,rentalId);}
            ps.setInt(3,limit);ps.setQueryTimeout(10);return rows(ps);
        }
    }

    public Map<String,Object> overdue(Connection c,LocalDateTime asOf,int limit) throws SQLException {
        // The installed explicit cursor emits DBMS_OUTPUT and two OUT aggregates, not a ref cursor.
        // Invoke it, then fetch structured rows with the same predicate in one read-only snapshot.
        try(PreparedStatement begin=c.prepareStatement("SET TRANSACTION READ ONLY")){
            begin.execute();
        }
        int count;BigDecimal outstanding;
        try(CallableStatement call=c.prepareCall("{call SVR_WORKFLOW.OVERDUE_REPORT(?,?,?)}")){
            call.setTimestamp(1,ts(asOf));call.registerOutParameter(2,Types.NUMERIC);
            call.registerOutParameter(3,Types.NUMERIC);call.setQueryTimeout(10);call.execute();
            count=call.getInt(2);outstanding=call.getBigDecimal(3);
        }
        String sql="SELECT r.Rental_ID,r.Customer_ID,r.Vehicle_ID,r.Expected_Return_Date,"
            +"r.Total_Amount-NVL((SELECT SUM(p.Amount) FROM PAYMENT p WHERE p.Rental_ID=r.Rental_ID "
            +"AND p.Payment_Status='Completed'),0) AS Estimated_Balance "
            +"FROM RENTAL r WHERE r.Status_Name='Active' AND r.Expected_Return_Date<? "
            +"ORDER BY r.Rental_ID FETCH FIRST ? ROWS ONLY";
        try(PreparedStatement ps=c.prepareStatement(sql)){
            ps.setTimestamp(1,ts(asOf));ps.setInt(2,limit);ps.setQueryTimeout(10);
            return Json.object("asOf",asOf.toString(),"count",count,
                "estimatedOutstanding",outstanding,"items",rows(ps));
        }
    }

    public List<Map<String,Object>> revenue(Connection c,String basis,int limit) throws SQLException {
        String sql;
        if("cash".equals(basis)){
            sql="SELECT b.Branch_ID,b.Branch_Name,SUM(p.Amount) AS Amount,COUNT(*) AS Record_Count "
                +"FROM PAYMENT p JOIN RENTAL r ON r.Rental_ID=p.Rental_ID "
                +"JOIN VEHICLE v ON v.Vehicle_ID=r.Vehicle_ID JOIN BRANCH b ON b.Branch_ID=v.Branch_ID "
                +"WHERE p.Payment_Status='Completed' AND r.Status_Name<>'Cancelled' "
                +"GROUP BY b.Branch_ID,b.Branch_Name ORDER BY b.Branch_ID FETCH FIRST ? ROWS ONLY";
        }else if("recognized".equals(basis)){
            sql="SELECT b.Branch_ID,b.Branch_Name,SUM(r.Total_Amount) AS Amount,COUNT(*) AS Record_Count "
                +"FROM RENTAL r JOIN VEHICLE v ON v.Vehicle_ID=r.Vehicle_ID "
                +"JOIN BRANCH b ON b.Branch_ID=v.Branch_ID WHERE r.Status_Name='Completed' "
                +"GROUP BY b.Branch_ID,b.Branch_Name ORDER BY b.Branch_ID FETCH FIRST ? ROWS ONLY";
        }else throw new ApiException(400,"invalid_field","basis must be cash or recognized.");
        try(PreparedStatement ps=c.prepareStatement(sql)){
            ps.setInt(1,limit);ps.setQueryTimeout(10);return rows(ps);
        }
    }
    private List<Map<String,Object>> rows(PreparedStatement ps) throws SQLException {
        try(ResultSet rs=ps.executeQuery()){
            List<Map<String,Object>> rows=new ArrayList<>();
            while(rs.next())rows.add(JdbcRows.map(rs));
            return rows;
        }
    }
}
