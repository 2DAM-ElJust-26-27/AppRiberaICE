package ribera.api;

import io.javalin.Javalin;
import io.javalin.http.Context;
import io.javalin.http.HttpStatus;
import ribera.api.Models.Error;

import java.util.Map;
import java.util.Optional;

/**
 * Rutes REST de només lectura (part d'usuari, sense administració).
 *
 *   GET /api/salut
 *   GET /api/municipis
 *   GET /api/catalegs
 *   GET /api/serveis?q=&municipi={id}&collectiu={codi}&tipus_centre={codi}
 *   GET /api/serveis/{id}
 *   GET /api/centres?q=&municipi={id}&collectiu={codi}&tipus_centre={codi}&amb_punt=true
 *   GET /api/centres/{id}
 *   GET /api/entitats?q=
 *   GET /api/entitats/{id}
 */
public final class Rutes {

    private Rutes() {}

    public static void registra(Javalin app, Directori dir) {
        app.get("/api/salut", ctx -> ctx.json(Map.of("estat", "ok")));
        app.get("/api/municipis", ctx -> ctx.json(dir.municipis()));
        app.get("/api/catalegs", ctx -> ctx.json(dir.catalegs()));

        app.get("/api/serveis", ctx -> ctx.json(dir.serveis(filtres(ctx))));
        app.get("/api/serveis/{id}", ctx -> retorna(ctx, dir.servei(id(ctx)), "servei"));

        app.get("/api/centres", ctx -> ctx.json(dir.centres(filtres(ctx))));
        app.get("/api/centres/{id}", ctx -> retorna(ctx, dir.centre(id(ctx)), "centre"));

        app.get("/api/entitats", ctx -> ctx.json(dir.entitats(ctx.queryParam("q"))));
        app.get("/api/entitats/{id}", ctx -> retorna(ctx, dir.entitat(id(ctx)), "entitat"));

        app.exception(ParametreInvalid.class, (e, ctx) ->
                ctx.status(HttpStatus.BAD_REQUEST).json(new Error(e.getMessage())));
        app.exception(Exception.class, (e, ctx) -> {
            e.printStackTrace();
            ctx.status(HttpStatus.INTERNAL_SERVER_ERROR).json(new Error("Error intern del servidor"));
        });
        app.error(HttpStatus.NOT_FOUND, ctx -> {
            String actual = ctx.result();
            if (actual == null || !actual.startsWith("{")) ctx.json(new Error("Ruta no trobada"));
        });
    }

    static final class ParametreInvalid extends RuntimeException {
        ParametreInvalid(String m) { super(m); }
    }

    private static void retorna(Context ctx, Optional<?> valor, String tipus) {
        if (valor.isPresent()) ctx.json(valor.get());
        else ctx.status(HttpStatus.NOT_FOUND).json(new Error("No existeix cap " + tipus + " amb aquest id"));
    }

    private static long id(Context ctx) {
        try {
            return Long.parseLong(ctx.pathParam("id"));
        } catch (NumberFormatException e) {
            throw new ParametreInvalid("L'id ha de ser un número");
        }
    }

    private static Directori.Filtres filtres(Context ctx) {
        Long municipi = null;
        String m = buit(ctx.queryParam("municipi"));
        if (m != null) {
            try { municipi = Long.parseLong(m); } catch (NumberFormatException e) {
                throw new ParametreInvalid("El paràmetre municipi ha de ser l'id numèric del municipi");
            }
        }
        return new Directori.Filtres(buit(ctx.queryParam("q")), municipi, buit(ctx.queryParam("collectiu")),
                buit(ctx.queryParam("tipus_centre")), "true".equalsIgnoreCase(ctx.queryParam("amb_punt")));
    }

    private static String buit(String s) {
        return (s == null || s.isBlank()) ? null : s.trim();
    }
}
