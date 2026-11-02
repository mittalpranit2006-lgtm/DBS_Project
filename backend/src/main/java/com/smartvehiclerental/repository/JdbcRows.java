package com.smartvehiclerental.repository;

import java.sql.Date;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.LinkedHashMap;
import java.util.Map;

public final class JdbcRows {
    private JdbcRows() {}
    public static Map<String, Object> map(ResultSet rs) throws SQLException {
        ResultSetMetaData md = rs.getMetaData();
        Map<String, Object> row = new LinkedHashMap<>();
        for (int i = 1; i <= md.getColumnCount(); i++) {
            Object value;
            int sqlType = md.getColumnType(i);
            if (sqlType == Types.TIMESTAMP || sqlType == Types.TIMESTAMP_WITH_TIMEZONE || sqlType == Types.DATE) {
                Timestamp timestamp = rs.getTimestamp(i);
                value = timestamp == null ? null : timestamp.toLocalDateTime().toString();
            } else if (sqlType == Types.NUMERIC || sqlType == Types.DECIMAL) {
                value = rs.getBigDecimal(i);
            } else {
                value = rs.getObject(i);
            }
            if (value instanceof Timestamp ts) value = ts.toLocalDateTime().toString();
            else if (value instanceof Date d) value = d.toLocalDate().toString();
            row.put(camel(md.getColumnLabel(i)), value);
        }
        return row;
    }
    public static String camel(String column) {
        StringBuilder out = new StringBuilder();
        boolean upper = false;
        for (char ch : column.toLowerCase().toCharArray()) {
            if (ch == '_') upper = true;
            else { out.append(upper ? Character.toUpperCase(ch) : ch); upper = false; }
        }
        return out.toString();
    }
}
