package com.smartvehiclerental.service;

import com.smartvehiclerental.config.Database;
import com.sun.net.httpserver.HttpExchange;
import java.sql.Connection;
import java.sql.SQLException;

/** Request transaction boundary shared by the three member modules. */
public final class TransactionService {
    @FunctionalInterface public interface Work<T> { T run(Connection connection) throws SQLException; }

    private final Database database;
    public TransactionService(Database database) { this.database=database; }

    public <T> T read(Work<T> action) throws SQLException {
        try(Connection c=database.open()) { return action.run(c); }
    }

    public <T> T readSnapshot(Work<T> action) throws SQLException {
        try(Connection c=database.open()) {
            c.setAutoCommit(false);
            try { return action.run(c); }
            finally { c.rollback(); }
        }
    }

    public <T> T write(HttpExchange exchange, Work<T> action) throws SQLException {
        try(Connection c=database.open()) {
            c.setAutoCommit(false);
            try {
                T result=action.run(c);
                boolean rollbackTest="true".equalsIgnoreCase(System.getenv("SVR_TEST_MODE"))
                    && "true".equalsIgnoreCase(exchange.getRequestHeaders().getFirst("X-SVR-Rollback"));
                if(rollbackTest) {
                    c.rollback();
                    exchange.getResponseHeaders().set("X-SVR-Rolled-Back","true");
                } else c.commit();
                return result;
            } catch(SQLException|RuntimeException ex) {
                c.rollback();
                throw ex;
            }
        }
    }
}
