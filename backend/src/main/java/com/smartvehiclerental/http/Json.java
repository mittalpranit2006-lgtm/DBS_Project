package com.smartvehiclerental.http;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpExchange;
import java.io.IOException;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import java.util.LinkedHashMap;
import java.util.Map;

public final class Json {
    public static final ObjectMapper MAPPER = new ObjectMapper();
    private Json() {}

    public static JsonNode body(HttpExchange exchange) throws IOException {
        String contentType = exchange.getRequestHeaders().getFirst("Content-Type");
        if (contentType == null || !contentType.toLowerCase().startsWith("application/json"))
            throw new ApiException(415, "unsupported_media_type", "Use application/json.");
        byte[] bytes = exchange.getRequestBody().readNBytes(65537);
        if (bytes.length > 65536) throw new ApiException(413, "too_large", "JSON body exceeds 64 KiB.");
        try {
            JsonNode node = MAPPER.readTree(bytes);
            if (node == null || !node.isObject()) throw new ApiException(400, "invalid_json", "Expected a JSON object.");
            return node;
        } catch (JsonProcessingException ex) {
            throw new ApiException(400, "invalid_json", "Malformed JSON.");
        }
    }

    public static long positiveId(JsonNode body, String field, long maximum) {
        JsonNode n = body.get(field);
        if (n == null || !n.isIntegralNumber() || !n.canConvertToLong() || n.longValue() <= 0 || n.longValue() > maximum)
            throw new ApiException(400, "invalid_field", field + " must be a positive integer at most " + maximum + ".");
        return n.longValue();
    }

    public static long pathId(String raw, long maximum) {
        try {
            long id = Long.parseLong(raw);
            if (id <= 0 || id > maximum) throw new NumberFormatException();
            return id;
        } catch (NumberFormatException ex) {
            throw new ApiException(400, "invalid_id", "Invalid record ID.");
        }
    }

    public static String string(JsonNode body, String field, int max) {
        JsonNode n = body.get(field);
        if (n == null || !n.isTextual() || n.textValue().isBlank() || n.textValue().length() > max)
            throw new ApiException(400, "invalid_field", field + " is required and must be at most " + max + " characters.");
        return n.textValue().trim();
    }

    public static BigDecimal money(JsonNode body, String field, boolean positive) {
        JsonNode n = body.get(field);
        if (n == null || !n.isNumber()) throw new ApiException(400, "invalid_field", field + " must be a number.");
        BigDecimal value = n.decimalValue();
        if (value.scale() > 2 || value.precision() > 12 || (positive ? value.signum() <= 0 : value.signum() < 0))
            throw new ApiException(400, "invalid_field", field + " has an invalid monetary value.");
        return value;
    }

    public static LocalDate date(JsonNode body, String field) {
        try { return LocalDate.parse(string(body, field, 10)); }
        catch (DateTimeParseException ex) { throw new ApiException(400, "invalid_date", field + " must be YYYY-MM-DD."); }
    }

    public static LocalDateTime timestamp(JsonNode body, String field) {
        try {
            LocalDateTime value = LocalDateTime.parse(string(body, field, 25));
            if (value.getNano() != 0) throw new DateTimeParseException("Fractional seconds", value.toString(), 0);
            return value;
        }
        catch (DateTimeParseException ex) { throw new ApiException(400, "invalid_date", field + " must be ISO local date-time."); }
    }

    public static Map<String, Object> object(Object... pairs) {
        Map<String, Object> result = new LinkedHashMap<>();
        for (int i = 0; i < pairs.length; i += 2) result.put((String) pairs[i], pairs[i + 1]);
        return result;
    }

    public static void send(HttpExchange exchange, int status, Object body) throws IOException {
        byte[] bytes = MAPPER.writeValueAsBytes(body);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=UTF-8");
        exchange.getResponseHeaders().set("X-Content-Type-Options", "nosniff");
        exchange.sendResponseHeaders(status, bytes.length);
        try (OutputStream out = exchange.getResponseBody()) { out.write(bytes); }
    }

    public static void error(HttpExchange exchange, int status, String code, String message) throws IOException {
        send(exchange, status, object("error", object("code", code, "message", message)));
    }
}
