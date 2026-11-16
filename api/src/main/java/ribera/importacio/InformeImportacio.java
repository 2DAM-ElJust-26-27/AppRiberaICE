package ribera.importacio;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Resultat d'una importació: errors, avisos, recomptes i comprovacions. */
public class InformeImportacio {

    public final List<String> errors = new ArrayList<>();
    public final List<String> avisos = new ArrayList<>();
    /** Registres nous inserits en aquesta execució, per tipus. */
    public final Map<String, Integer> nous = new LinkedHashMap<>();
    /** Recompte final a la base de dades vs esperat pel manifest. */
    public final Map<String, long[]> recomptes = new LinkedHashMap<>();
    /** Comprovació -> [esperat, obtingut]. */
    public final Map<String, List<List<String>>> comprovacions = new LinkedHashMap<>();

    public void error(String fitxer, String cami, String missatge) {
        errors.add(fitxer + " · " + cami + ": " + missatge);
    }

    public void nou(String tipus) {
        nous.merge(tipus, 1, Integer::sum);
    }

    public boolean correcte() {
        return errors.isEmpty();
    }

    public boolean recomptesCorrectes() {
        return recomptes.values().stream().allMatch(v -> v[0] == v[1]);
    }

    public boolean comprovacionsCorrectes() {
        return comprovacions.values().stream().allMatch(v -> v.get(0).equals(v.get(1)));
    }

    public String resum() {
        StringBuilder sb = new StringBuilder();
        sb.append("== Importació ").append(correcte() ? "CORRECTA" : "AMB ERRORS (s'ha desfet)").append(" ==\n");
        errors.forEach(e -> sb.append("  [ERROR] ").append(e).append('\n'));
        avisos.forEach(a -> sb.append("  [AVÍS] ").append(a).append('\n'));
        if (!nous.isEmpty()) sb.append("  Registres nous: ").append(nous).append('\n');
        if (!recomptes.isEmpty()) {
            sb.append("  Recomptes (esperat / a la BD):\n");
            recomptes.forEach((k, v) -> sb.append(String.format("    %-20s %4d / %4d %s%n", k, v[0], v[1], v[0] == v[1] ? "OK" : "DIFERENT")));
        }
        if (!comprovacions.isEmpty()) {
            sb.append("  Comprovacions:\n");
            comprovacions.forEach((k, v) -> sb.append(String.format("    %-28s %s esperat=%s obtingut=%s%n", k,
                    v.get(0).equals(v.get(1)) ? "OK      " : "DIFERENT", v.get(0), v.get(1))));
        }
        return sb.toString();
    }
}
