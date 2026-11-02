package com.smartvehiclerental.config;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;

/** One short-lived connection per request; no shared mutable JDBC session. */
public final class Database {
    private final String url = System.getenv("SVR_DB_URL");
    private final String user = System.getenv("SVR_DB_USER");
    private final String password = System.getenv("SVR_DB_PASSWORD");

    public boolean configured() {
        return url != null && !url.isBlank() && "SVR_APP".equalsIgnoreCase(user)
                && password != null && !password.isEmpty();
    }

    public Connection open() throws SQLException {
        if (!configured()) throw new SQLException("Database configuration is unavailable", "08001");
        Properties props = new Properties();
        props.setProperty("user", user);
        props.setProperty("password", password);
        props.setProperty("oracle.net.CONNECT_TIMEOUT", "5000");
        props.setProperty("oracle.jdbc.ReadTimeout", "10000");
        DriverManager.setLoginTimeout(5);
        return DriverManager.getConnection(url, props);
    }
}
