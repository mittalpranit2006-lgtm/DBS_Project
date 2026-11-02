package com.smartvehiclerental.repository;

import com.fasterxml.jackson.databind.JsonNode;
import com.smartvehiclerental.http.ApiException;
import com.smartvehiclerental.http.Json;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Whitelisted master-table SQL. IDs are client supplied; Oracle PKs reject collisions. */
public final class MasterRepository {
    public record Field(String json, String sql, String kind, int max) {}
    public record Model(String path, String table, String idSql, String idJson,
                        long maxId, List<Field> fields, List<String> searchColumns) {}

    private static Field f(String json, String sql, String kind, int max) { return new Field(json,sql,kind,max); }
    private static final Map<String, Model> MODELS = new LinkedHashMap<>();
    static {
        add(new Model("customers","CUSTOMER","Customer_ID","customerId",999999,List.of(
            f("firstName","First_Name","text",60), f("lastName","Last_Name","text",60),
            f("email","Email","email",254), f("licenseNo","License_No","text",24),
            f("address","Address","text",240), f("registrationDate","Registration_Date","date",0)),
            List.of("First_Name","Last_Name","Email","License_No")));
        add(new Model("vehicle-types","VEHICLE_TYPE","Type_ID","typeId",9999,List.of(
            f("typeName","Type_Name","text",60), f("dailyRate","Daily_Rate","positiveMoney",0),
            f("securityDeposit","Security_Deposit","money",0)),List.of("Type_Name")));
        add(new Model("branches","BRANCH","Branch_ID","branchId",9999,List.of(
            f("branchName","Branch_Name","text",80), f("location","Location","text",160),
            f("phone","Phone","phone",15)),List.of("Branch_Name","Location","Phone")));
        add(new Model("vehicles","VEHICLE","Vehicle_ID","vehicleId",999999,List.of(
            f("registrationNo","Registration_No","text",24), f("brand","Brand","text",60),
            f("model","Model","text",60), f("purchaseYear","Purchase_Year","year",0),
            f("availabilityStatus","Availability_Status","vehicleStatus",0),
            f("typeId","Type_ID","id4",0), f("branchId","Branch_ID","id4",0)),
            List.of("Registration_No","Brand","Model","Availability_Status")));
        add(new Model("employees","EMPLOYEE","Employee_ID","employeeId",999999,List.of(
            f("name","Name","text",120), f("email","Email","email",254),
            f("phone","Phone","phone",15), f("role","\"ROLE\"","text",40),
            f("branchId","Branch_ID","id4",0)),List.of("Name","Email","Phone","\"ROLE\"")));
    }
    private static void add(Model m) { MODELS.put(m.path, m); }
    public static Model model(String path) { return MODELS.get(path); }

    private static Object value(JsonNode body, Field field) {
        return switch (field.kind) {
            case "text" -> Json.string(body,field.json,field.max);
            case "email" -> {
                String value=Json.string(body,field.json,field.max);
                if (!value.matches("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"))
                    throw new ApiException(400,"invalid_field",field.json+" must be an email address.");
                yield value;
            }
            case "phone" -> {
                String value=Json.string(body,field.json,15);
                if (!value.matches("[0-9]{10,15}"))
                    throw new ApiException(400,"invalid_field",field.json+" must have 10–15 digits.");
                yield value;
            }
            case "date" -> Date.valueOf(Json.date(body,field.json));
            case "money" -> Json.money(body,field.json,false);
            case "positiveMoney" -> Json.money(body,field.json,true);
            case "id4" -> Json.positiveId(body,field.json,9999);
            case "year" -> {
                long year=Json.positiveId(body,field.json,2100);
                if (year<1990) throw new ApiException(400,"invalid_field","purchaseYear must be 1990–2100.");
                yield year;
            }
            case "vehicleStatus" -> {
                String value=Json.string(body,field.json,16);
                if (!List.of("Available","Rented","Maintenance").contains(value))
                    throw new ApiException(400,"invalid_field","Invalid vehicle availability status.");
                yield value;
            }
            default -> throw new IllegalStateException("Unknown field kind");
        };
    }

    private static List<Object> fields(JsonNode body, Model m) {
        List<Object> values=new ArrayList<>();
        for (Field f:m.fields) values.add(value(body,f));
        return values;
    }

    public Map<String,Object> create(Connection c, Model m, JsonNode body) throws SQLException {
        long id=Json.positiveId(body,m.idJson,m.maxId);
        List<Object> values=fields(body,m);
        StringBuilder cols=new StringBuilder(m.idSql), marks=new StringBuilder("?");
        for(Field f:m.fields){cols.append(',').append(f.sql);marks.append(",?");}
        String sql="INSERT INTO "+m.table+"("+cols+") VALUES("+marks+")";
        try(PreparedStatement ps=c.prepareStatement(sql)){
            ps.setLong(1,id);
            for(int i=0;i<values.size();i++) ps.setObject(i+2,values.get(i));
            ps.setQueryTimeout(10); ps.executeUpdate();
        }
        return detail(c,m,id);
    }

    public Map<String,Object> update(Connection c, Model m, long id, JsonNode body) throws SQLException {
        List<Object> values=fields(body,m);
        StringBuilder sets=new StringBuilder();
        for(Field f:m.fields){if(!sets.isEmpty())sets.append(',');sets.append(f.sql).append("=?");}
        try(PreparedStatement ps=c.prepareStatement("UPDATE "+m.table+" SET "+sets+" WHERE "+m.idSql+"=?")){
            for(int i=0;i<values.size();i++)ps.setObject(i+1,values.get(i));
            ps.setLong(values.size()+1,id);ps.setQueryTimeout(10);
            if(ps.executeUpdate()==0)throw new ApiException(404,"not_found","Record not found.");
        }
        return detail(c,m,id);
    }

    public void delete(Connection c, Model m, long id) throws SQLException {
        try(PreparedStatement ps=c.prepareStatement("DELETE FROM "+m.table+" WHERE "+m.idSql+"=?")){
            ps.setLong(1,id);ps.setQueryTimeout(10);
            if(ps.executeUpdate()==0)throw new ApiException(404,"not_found","Record not found.");
        }
    }

    public Map<String,Object> detail(Connection c, Model m, long id) throws SQLException {
        try(PreparedStatement ps=c.prepareStatement("SELECT * FROM "+m.table+" WHERE "+m.idSql+"=?")){
            ps.setLong(1,id);ps.setQueryTimeout(10);
            try(ResultSet rs=ps.executeQuery()){
                if(!rs.next())throw new ApiException(404,"not_found","Record not found.");
                return JdbcRows.map(rs);
            }
        }
    }

    public List<Map<String,Object>> list(Connection c,Model m,String q,int limit) throws SQLException {
        StringBuilder sql=new StringBuilder("SELECT * FROM "+m.table);
        boolean searching=q!=null&&!q.isBlank();
        if(searching){
            sql.append(" WHERE ");
            for(String col:m.searchColumns){if(!sql.toString().endsWith(" WHERE "))sql.append(" OR ");sql.append("UPPER(").append(col).append(") LIKE ?");}
        }
        sql.append(" ORDER BY ").append(m.idSql).append(" FETCH FIRST ? ROWS ONLY");
        try(PreparedStatement ps=c.prepareStatement(sql.toString())){
            int p=1;
            if(searching)for(int i=0;i<m.searchColumns.size();i++)ps.setString(p++,"%"+q.toUpperCase()+"%");
            ps.setInt(p,limit);ps.setQueryTimeout(10);
            try(ResultSet rs=ps.executeQuery()){
                List<Map<String,Object>> rows=new ArrayList<>();
                while(rs.next())rows.add(JdbcRows.map(rs));
                return rows;
            }
        }
    }

    public List<Map<String,Object>> phones(Connection c,long customerId) throws SQLException {
        try(PreparedStatement ps=c.prepareStatement("SELECT Customer_ID,Phone_No FROM CUSTOMER_PHONE WHERE Customer_ID=? ORDER BY Phone_No")){
            ps.setLong(1,customerId);ps.setQueryTimeout(10);
            try(ResultSet rs=ps.executeQuery()){
                List<Map<String,Object>> rows=new ArrayList<>();
                while(rs.next())rows.add(JdbcRows.map(rs));
                return rows;
            }
        }
    }
    public Map<String,Object> addPhone(Connection c,long customerId,String phone) throws SQLException {
        try(PreparedStatement ps=c.prepareStatement("INSERT INTO CUSTOMER_PHONE(Customer_ID,Phone_No) VALUES(?,?)")){
            ps.setLong(1,customerId);ps.setString(2,phone);ps.setQueryTimeout(10);ps.executeUpdate();
        }
        return Json.object("customerId",customerId,"phoneNo",phone);
    }
    public Map<String,Object> updatePhone(Connection c,long customerId,String oldPhone,String newPhone) throws SQLException {
        try(PreparedStatement ps=c.prepareStatement("UPDATE CUSTOMER_PHONE SET Phone_No=? WHERE Customer_ID=? AND Phone_No=?")){
            ps.setString(1,newPhone);ps.setLong(2,customerId);ps.setString(3,oldPhone);ps.setQueryTimeout(10);
            if(ps.executeUpdate()==0)throw new ApiException(404,"not_found","Phone not found.");
        }
        return Json.object("customerId",customerId,"phoneNo",newPhone);
    }
    public void deletePhone(Connection c,long customerId,String phone) throws SQLException {
        try(PreparedStatement ps=c.prepareStatement("DELETE FROM CUSTOMER_PHONE WHERE Customer_ID=? AND Phone_No=?")){
            ps.setLong(1,customerId);ps.setString(2,phone);ps.setQueryTimeout(10);
            if(ps.executeUpdate()==0)throw new ApiException(404,"not_found","Phone not found.");
        }
    }
}
