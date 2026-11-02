package com.smartvehiclerental.http;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.exc.InvalidDefinitionException;
import com.smartvehiclerental.config.Database;
import com.smartvehiclerental.repository.MasterRepository;
import com.smartvehiclerental.repository.WorkflowRepository;
import com.smartvehiclerental.service.TransactionService;
import com.sun.net.httpserver.HttpExchange;
import java.io.IOException;
import java.math.BigDecimal;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Same-origin JSON controller; SQL remains in repositories. */
public final class ApiController {
    private final Database database=new Database();
    private final TransactionService service=new TransactionService(database);
    private final MasterRepository masters=new MasterRepository();
    private final WorkflowRepository workflows=new WorkflowRepository();

    public void handle(HttpExchange exchange) throws IOException {
        try {
            route(exchange);
        } catch(ApiException ex) {
            Json.error(exchange,ex.status(),ex.code(),ex.getMessage());
        } catch(SQLException ex) {
            ApiException mapped=mapSql(ex);
            Json.error(exchange,mapped.status(),mapped.code(),mapped.getMessage());
        } catch(Exception ex) {
            StackTraceElement at=ex.getStackTrace().length==0?null:ex.getStackTrace()[0];
            System.err.println("API_INTERNAL " + ex.getClass().getSimpleName()
                + " at " + (at==null?"unknown":at.getClassName()+":"+at.getLineNumber()));
            if(ex instanceof InvalidDefinitionException mapping)
                System.err.println("API_JSON_TYPE " + mapping.getType() + " path=" + mapping.getPathReference());
            Json.error(exchange,500,"internal_error","Request could not be completed.");
        }
    }

    private void route(HttpExchange x) throws IOException,SQLException {
        String path=x.getRequestURI().getPath();
        String method=x.getRequestMethod();
        Map<String,String> query=query(x);
        if(path.equals("/api/health")){
            requireMethod(method,"GET");Json.send(x,200,Json.object("status","ok","service","smart-vehicle-rental",
                "testMode","true".equalsIgnoreCase(System.getenv("SVR_TEST_MODE"))));return;
        }
        if(path.equals("/api/health/database")){
            requireMethod(method,"GET");
            Map<String,Object> state=service.read(c->{
                try(PreparedStatement ps=c.prepareStatement("SELECT USER AS ACCOUNT,SYS_CONTEXT('USERENV','CON_NAME') AS PDB FROM DUAL")){
                    ps.setQueryTimeout(5);
                    try(ResultSet rs=ps.executeQuery()){
                        rs.next();return Json.object("status","ok","account",rs.getString(1),"pdb",rs.getString(2));
                    }
                }
            });
            Json.send(x,200,state);return;
        }
        if(path.equals("/api/dashboard")){
            requireMethod(method,"GET");
            Json.send(x,200,service.read(workflows::dashboard));return;
        }
        if(path.startsWith("/api/reports/")){reports(x,method,path.substring(13),query);return;}
        String[] parts=path.split("/");
        if(parts.length<3||!parts[1].equals("api"))throw new ApiException(404,"not_found","Endpoint not found.");
        if(parts[2].equals("rentals")){rentals(x,method,parts,query);return;}
        if(parts[2].equals("payments")){payments(x,method,parts,query);return;}
        MasterRepository.Model model=MasterRepository.model(parts[2]);
        if(model==null)throw new ApiException(404,"not_found","Endpoint not found.");
        if(parts[2].equals("customers")&&parts.length>=5&&parts[4].equals("phones")){
            phones(x,method,parts);return;
        }
        masters(x,method,parts,model,query);
    }

    private void masters(HttpExchange x,String method,String[] p,MasterRepository.Model m,Map<String,String> q)
            throws IOException,SQLException {
        if(p.length==3){
            if(method.equals("GET")){
                String search=q.get("q");
                if(search!=null&&search.length()>100)throw new ApiException(400,"invalid_field","q is too long.");
                Json.send(x,200,Json.object("items",service.read(c->masters.list(c,m,search,limit(q)))));return;
            }
            if(method.equals("POST")){
                JsonNode body=Json.body(x);
                Json.send(x,201,service.write(x,c->masters.create(c,m,body)));return;
            }
            throw methodError();
        }
        if(p.length!=4)throw new ApiException(404,"not_found","Endpoint not found.");
        long id=Json.pathId(p[3],m.maxId());
        switch(method){
            case "GET" -> Json.send(x,200,service.read(c->masters.detail(c,m,id)));
            case "PUT" -> {JsonNode body=Json.body(x);Json.send(x,200,service.write(x,c->masters.update(c,m,id,body)));}
            case "DELETE" -> {service.write(x,c->{masters.delete(c,m,id);return null;});Json.send(x,200,Json.object("deleted",true,"id",id));}
            default -> throw methodError();
        }
    }

    private void phones(HttpExchange x,String method,String[] p) throws IOException,SQLException {
        long customer=Json.pathId(p[3],999999);
        if(p.length==5){
            if(method.equals("GET")){Json.send(x,200,Json.object("items",service.read(c->masters.phones(c,customer))));return;}
            if(method.equals("POST")){
                JsonNode body=Json.body(x);String phone=phone(Json.string(body,"phoneNo",15));
                Json.send(x,201,service.write(x,c->masters.addPhone(c,customer,phone)));return;
            }
            throw methodError();
        }
        if(p.length!=6)throw new ApiException(404,"not_found","Endpoint not found.");
        String oldPhone=phone(p[5]);
        if(method.equals("PUT")){
            JsonNode body=Json.body(x);String newPhone=phone(Json.string(body,"newPhoneNo",15));
            Json.send(x,200,service.write(x,c->masters.updatePhone(c,customer,oldPhone,newPhone)));return;
        }
        if(method.equals("DELETE")){
            service.write(x,c->{masters.deletePhone(c,customer,oldPhone);return null;});
            Json.send(x,200,Json.object("deleted",true));return;
        }
        throw methodError();
    }

    private void rentals(HttpExchange x,String method,String[] p,Map<String,String> q) throws IOException,SQLException {
        if(p.length==3){
            requireMethod(method,"GET");
            Long customer=optionalId(q,"customerId",999999),vehicle=optionalId(q,"vehicleId",999999);
            String status=q.get("status");
            if(status!=null&&!List.of("Active","Completed","Cancelled").contains(status))
                throw new ApiException(400,"invalid_field","Invalid rental status.");
            int max=limit(q);
            Json.send(x,200,Json.object("items",service.read(c->workflows.rentals(c,customer,vehicle,status,max))));return;
        }
        if(p.length==4&&p[3].equals("start")){
            requireMethod(method,"POST");JsonNode b=Json.body(x);
            long customer=Json.positiveId(b,"customerId",999999),vehicle=Json.positiveId(b,"vehicleId",999999);
            long employee=Json.positiveId(b,"employeeId",999999);
            LocalDateTime start=Json.timestamp(b,"startDate"),expected=Json.timestamp(b,"expectedReturnDate");
            if(!expected.isAfter(start))throw new ApiException(400,"invalid_date","Expected return must follow start.");
            Json.send(x,201,service.write(x,c->workflows.start(c,customer,vehicle,employee,start,expected)));return;
        }
        if(p.length==4){
            requireMethod(method,"GET");long id=Json.pathId(p[3],99999999);
            Json.send(x,200,service.read(c->workflows.rental(c,id)));return;
        }
        if(p.length==5&&p[4].equals("return")){
            requireMethod(method,"POST");long id=Json.pathId(p[3],99999999);
            LocalDateTime actual=Json.timestamp(Json.body(x),"actualReturnDate");
            Json.send(x,200,service.write(x,c->workflows.recordReturn(c,id,actual)));return;
        }
        throw new ApiException(404,"not_found","Endpoint not found.");
    }

    private void payments(HttpExchange x,String method,String[] p,Map<String,String> q) throws IOException,SQLException {
        if(p.length==3){
            if(method.equals("GET")){
                Long rental=optionalId(q,"rentalId",99999999);int max=limit(q);
                Json.send(x,200,Json.object("items",service.read(c->workflows.payments(c,rental,max))));return;
            }
            if(method.equals("POST")){
                JsonNode b=Json.body(x);long rental=Json.positiveId(b,"rentalId",99999999);
                BigDecimal amount=Json.money(b,"amount",true);String paymentMethod=Json.string(b,"paymentMethod",20);
                if(!List.of("Card","UPI","Cash","Bank Transfer").contains(paymentMethod))
                    throw new ApiException(400,"invalid_field","Invalid payment method.");
                LocalDateTime date=Json.timestamp(b,"paymentDate");
                Json.send(x,201,service.write(x,c->workflows.recordPayment(c,rental,amount,paymentMethod,date)));return;
            }
            throw methodError();
        }
        if(p.length==4){requireMethod(method,"GET");long id=Json.pathId(p[3],99999999);
            Json.send(x,200,service.read(c->workflows.payment(c,id)));return;}
        throw new ApiException(404,"not_found","Endpoint not found.");
    }

    private void reports(HttpExchange x,String method,String report,Map<String,String> q) throws IOException,SQLException {
        requireMethod(method,"GET");
        if(report.equals("charge-estimate")){
            LocalDateTime start=queryDate(q,"start"),end=queryDate(q,"end");
            BigDecimal rate=queryMoney(q,"rate");
            Json.send(x,200,Json.object("charge",service.read(c->workflows.charge(c,start,end,rate))));return;
        }
        if(report.equals("outstanding")){
            long id=requiredId(q,"rentalId",99999999);
            Json.send(x,200,Json.object("rentalId",id,"outstandingBalance",service.read(c->workflows.balance(c,id))));return;
        }
        if(report.equals("overdue")){
            LocalDateTime asOf=q.containsKey("asOf")?queryDate(q,"asOf"):LocalDateTime.now().withNano(0);
            int max=limit(q);Json.send(x,200,service.readSnapshot(c->workflows.overdue(c,asOf,max)));return;
        }
        if(report.equals("revenue")){
            String basis=q.getOrDefault("basis","cash");int max=limit(q);
            Json.send(x,200,Json.object("basis",basis,"items",service.read(c->workflows.revenue(c,basis,max))));return;
        }
        throw new ApiException(404,"not_found","Report not found.");
    }

    private static void requireMethod(String actual,String expected){
        if(!actual.equals(expected))throw methodError();
    }
    private static ApiException methodError(){return new ApiException(405,"method_not_allowed","Method not allowed for this endpoint.");}
    private static int limit(Map<String,String> q){
        String raw=q.getOrDefault("limit","50");
        try{int n=Integer.parseInt(raw);if(n<1||n>100)throw new NumberFormatException();return n;}
        catch(NumberFormatException ex){throw new ApiException(400,"invalid_field","limit must be 1–100.");}
    }
    private static Long optionalId(Map<String,String> q,String name,long max){
        return q.containsKey(name)?Json.pathId(q.get(name),max):null;
    }
    private static long requiredId(Map<String,String> q,String name,long max){
        if(!q.containsKey(name))throw new ApiException(400,"invalid_field",name+" is required.");
        return Json.pathId(q.get(name),max);
    }
    private static String phone(String raw){
        if(!raw.matches("[0-9]{10,15}"))throw new ApiException(400,"invalid_field","Phone must have 10–15 digits.");
        return raw;
    }
    private static LocalDateTime queryDate(Map<String,String> q,String name){
        String raw=q.get(name);
        if(raw==null)throw new ApiException(400,"invalid_field",name+" is required.");
        try {LocalDateTime date=LocalDateTime.parse(raw);if(date.getNano()!=0)throw new DateTimeParseException("Fractional seconds",raw,0);return date;}
        catch(DateTimeParseException ex){throw new ApiException(400,"invalid_date",name+" must be ISO local date-time to seconds.");}
    }
    private static BigDecimal queryMoney(Map<String,String> q,String name){
        try{BigDecimal value=new BigDecimal(q.get(name));if(value.signum()<=0||value.scale()>2)throw new NumberFormatException();return value;}
        catch(Exception ex){throw new ApiException(400,"invalid_field",name+" must be positive money.");}
    }
    private static Map<String,String> query(HttpExchange x){
        Map<String,String> result=new HashMap<>();String raw=x.getRequestURI().getRawQuery();
        if(raw==null||raw.isBlank())return result;
        for(String part:raw.split("&")){
            String[] kv=part.split("=",2);
            result.put(URLDecoder.decode(kv[0],StandardCharsets.UTF_8),
                URLDecoder.decode(kv.length==2?kv[1]:"",StandardCharsets.UTF_8));
        }
        return result;
    }

    private static ApiException mapSql(SQLException ex){
        int code=ex.getErrorCode();String state=ex.getSQLState();
        if("08001".equals(state)||code==1017||code==12514||code==12541||code==17002)
            return new ApiException(503,"database_unavailable","Database connection is unavailable.");
        if(code==1)return new ApiException(409,"duplicate","A record with this key or unique value already exists.");
        if(code==2292)return new ApiException(409,"referenced_record","Record is referenced by other records and cannot be deleted.");
        if(code==2291)return new ApiException(409,"invalid_reference","Referenced record does not exist.");
        if(code==1403)return new ApiException(404,"not_found","Record not found.");
        if(code==2290||code==1400||code==12899)return new ApiException(400,"invalid_field","Value violates a database constraint.");
        if(code==54||code==30006)return new ApiException(409,"busy","Record is busy; retry shortly.");
        if(code==20112||code==20115||code==20116||code==20118||code==20132||code==20135||code==20136||code==20140||code==20144||code==20163)
            return new ApiException(409,"business_conflict",businessMessage(code));
        if(code>=20110&&code<=20163)return new ApiException(400,"business_validation",businessMessage(code));
        return new ApiException(500,"database_error","Database operation failed.");
    }
    private static String businessMessage(int code){
        return switch(code){
            case 20111 -> "Rental dates are invalid.";
            case 20112 -> "Vehicle is unavailable.";
            case 20113 -> "Customer registration is later than rental start.";
            case 20114 -> "Employee belongs to another branch.";
            case 20115 -> "Rental interval overlaps another rental.";
            case 20116 -> "Rental is not active or vehicle is not rented.";
            case 20117 -> "Actual return date is invalid.";
            case 20118 -> "Final charge is below collected payments; refund workflow is unavailable.";
            case 20119,20141,20143 -> "Payment details or rental status are invalid.";
            case 20132 -> "Use the rental start workflow.";
            case 20135,20136 -> "Rental history is protected.";
            case 20140 -> "Payment history is protected.";
            case 20144 -> "Payment would exceed the rental bill.";
            case 20163 -> "Vehicle status transition requires the rental workflow.";
            default -> "Business rule rejected the operation.";
        };
    }
}

