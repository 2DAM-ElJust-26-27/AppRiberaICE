package ribera;

import java.nio.file.Path;

/** Configuració llegida de variables d'entorn (amb valors per defecte per a desenvolupament local). */
public record Configuracio(String bdUrl, String bdUsuari, String bdContrasenya, int port,
                           boolean importarEnArrancar, Path dirDades, Path dirComplements) {

    public static Configuracio desDeEntorn() {
        return new Configuracio(
                env("BD_URL", "jdbc:postgresql://localhost:5432/ribera"),
                env("BD_USUARI", "ribera"),
                env("BD_CONTRASENYA", "ribera"),
                Integer.parseInt(env("PORT", "8080")),
                Boolean.parseBoolean(env("IMPORTAR_EN_ARRANCAR", "false")),
                Path.of(env("DIR_DADES", "../dades/sprint-1")),
                Path.of(env("DIR_COMPLEMENTS", "../dades/complements")));
    }

    private static String env(String nom, String perDefecte) {
        String v = System.getenv(nom);
        return (v == null || v.isBlank()) ? perDefecte : v;
    }
}
