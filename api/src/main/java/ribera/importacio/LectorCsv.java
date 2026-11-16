package ribera.importacio;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Parser CSV (RFC 4180): separador coma, primera fila de capçalera,
 * cometes dobles amb l'escapat habitual ("" dins d'un camp entre cometes),
 * salts de línia dins de camps entre cometes.
 *
 * Convenció de les dades del sprint: el valor reservat \N (sense cometes)
 * és NUL; una cel·la buida és una cadena buida. No usem split(",").
 */
public final class LectorCsv {

    public static final String NUL = "\\N";

    private LectorCsv() {}

    public static List<Map<String, String>> llegeix(Path fitxer) throws IOException {
        return parseja(Files.readString(fitxer, StandardCharsets.UTF_8));
    }

    public static List<Map<String, String>> parseja(String text) {
        if (!text.isEmpty() && text.charAt(0) == '﻿') text = text.substring(1); // BOM
        List<List<Camp>> files = files(text);
        if (files.isEmpty()) return List.of();
        List<String> capcalera = new ArrayList<>();
        for (Camp c : files.get(0)) capcalera.add(c.text.trim());

        List<Map<String, String>> res = new ArrayList<>();
        for (int i = 1; i < files.size(); i++) {
            List<Camp> fila = files.get(i);
            if (fila.size() == 1 && fila.get(0).text.isEmpty() && !fila.get(0).entreCometes) continue; // línia buida
            if (fila.size() != capcalera.size()) {
                throw new IllegalArgumentException("Fila " + (i + 1) + ": s'esperaven " + capcalera.size()
                        + " columnes i n'hi ha " + fila.size());
            }
            Map<String, String> m = new LinkedHashMap<>();
            for (int j = 0; j < capcalera.size(); j++) {
                Camp c = fila.get(j);
                m.put(capcalera.get(j), (!c.entreCometes && NUL.equals(c.text)) ? null : c.text);
            }
            res.add(m);
        }
        return res;
    }

    private record Camp(String text, boolean entreCometes) {}

    private static List<List<Camp>> files(String t) {
        List<List<Camp>> files = new ArrayList<>();
        List<Camp> fila = new ArrayList<>();
        StringBuilder sb = new StringBuilder();
        boolean dinsCometes = false, campAmbCometes = false;
        int i = 0, n = t.length();
        while (i < n) {
            char ch = t.charAt(i);
            if (dinsCometes) {
                if (ch == '"') {
                    if (i + 1 < n && t.charAt(i + 1) == '"') { sb.append('"'); i += 2; continue; }
                    dinsCometes = false; i++; continue;
                }
                sb.append(ch); i++; continue;
            }
            switch (ch) {
                case '"' -> {
                    if (sb.length() > 0) throw new IllegalArgumentException("Cometa inesperada a la fila " + (files.size() + 1));
                    dinsCometes = true; campAmbCometes = true; i++;
                }
                case ',' -> { fila.add(new Camp(sb.toString(), campAmbCometes)); sb.setLength(0); campAmbCometes = false; i++; }
                case '\r' -> i++;
                case '\n' -> {
                    fila.add(new Camp(sb.toString(), campAmbCometes)); sb.setLength(0); campAmbCometes = false;
                    files.add(fila); fila = new ArrayList<>(); i++;
                }
                default -> {
                    if (campAmbCometes) throw new IllegalArgumentException("Text després de tancar cometes a la fila " + (files.size() + 1));
                    sb.append(ch); i++;
                }
            }
        }
        if (dinsCometes) throw new IllegalArgumentException("Cometes sense tancar al final del fitxer");
        if (sb.length() > 0 || campAmbCometes || !fila.isEmpty()) {
            fila.add(new Camp(sb.toString(), campAmbCometes));
            files.add(fila);
        }
        return files;
    }
}
