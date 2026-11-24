package ribera;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Llig un fitxer CSV. No podem fer split(",") perquè hi ha textos amb comes
 * entre cometes, com "Cullera, València".
 * Regla de les dades: \N sense cometes vol dir nul.
 */
public class LectorCsv {

    public static List<Map<String, String>> llegeix(Path fitxer) throws IOException {
        return parseja(Files.readString(fitxer));
    }

    /** Torna una llista de files. Cada fila és un mapa capçalera → valor. */
    public static List<Map<String, String>> parseja(String text) {
        List<List<String>> files = new ArrayList<>();
        List<String> fila = new ArrayList<>();
        StringBuilder camp = new StringBuilder();
        boolean dinsCometes = false;
        boolean teniaCometes = false;

        for (int i = 0; i < text.length(); i++) {
            char ch = text.charAt(i);
            if (dinsCometes) {
                if (ch == '"' && i + 1 < text.length() && text.charAt(i + 1) == '"') {
                    camp.append('"');   // "" dins de cometes és una cometa
                    i++;
                } else if (ch == '"') {
                    dinsCometes = false;
                } else {
                    camp.append(ch);    // dins de cometes, les comes i salts són text
                }
            } else if (ch == '"') {
                dinsCometes = true;
                teniaCometes = true;
            } else if (ch == ',' || ch == '\n') {
                fila.add(valor(camp, teniaCometes));
                camp.setLength(0);
                teniaCometes = false;
                if (ch == '\n') {
                    files.add(fila);
                    fila = new ArrayList<>();
                }
            } else if (ch != '\r') {
                camp.append(ch);
            }
        }
        if (camp.length() > 0 || !fila.isEmpty()) {   // última fila sense salt de línia
            fila.add(valor(camp, teniaCometes));
            files.add(fila);
        }

        // La primera fila és la capçalera
        List<String> capcalera = files.get(0);
        List<Map<String, String>> resultat = new ArrayList<>();
        for (int i = 1; i < files.size(); i++) {
            List<String> f = files.get(i);
            if (f.size() != capcalera.size()) {
                throw new IllegalArgumentException("La fila " + (i + 1) + " no té " + capcalera.size() + " columnes");
            }
            Map<String, String> mapa = new HashMap<>();
            for (int j = 0; j < capcalera.size(); j++) {
                mapa.put(capcalera.get(j), f.get(j));
            }
            resultat.add(mapa);
        }
        return resultat;
    }

    private static String valor(StringBuilder camp, boolean teniaCometes) {
        String text = camp.toString();
        if (!teniaCometes && text.equals("\\N")) return null;
        return text;
    }
}
