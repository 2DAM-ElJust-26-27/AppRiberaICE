package ribera.api;

import java.util.List;

/**
 * Objectes que retorna l'API (es serialitzen a JSON en snake_case).
 * Els camps «codi» són codis d'origen del paquet d'importació (poden ser nuls
 * per a fitxes creades fora del paquet); els «id» són els de PostgreSQL.
 */
public final class Models {

    private Models() {}

    /** Referència breu a un altre registre o a un valor de catàleg. */
    public record Ref(Long id, String codi, String nom) {}

    public record Font(String codi, String referencia) {}

    public record Municipi(long id, String codi, String nom, Ref comarca) {}

    public record Catalegs(List<Ref> collectius, List<Ref> tipusCentre, List<Ref> formesJuridiques, List<Ref> comarques) {}

    public record Contacte(String tipus, String valor) {}

    public record Franja(int diaSetmana, String horaInici, String horaFi, boolean finalDiaSeguent) {}

    public record Horari(String tipus, String descripcio, String zonaHoraria, String vigentDesDe, String vigentFinsA,
                         List<Franja> franges) {}

    public record ServeiResum(long id, String codi, String nom, String descripcio,
                              List<Ref> collectius, List<Ref> entitats, List<Ref> municipis, List<Ref> tipusCentre) {}

    public record CentreResum(long id, String codi, String nom, Ref tipusCentre, Ref municipi, String adreca,
                              String codiPostal, Double latitud, Double longitud, String precisioPunt) {}

    public record Prestacio(Ref entitat, Font font, List<CentreResum> centres) {}

    public record ServeiDetall(long id, String codi, String nom, String descripcio, String modalitatCodi,
                               String viaAcces, String cobertura, String imatge, String observacions, Font font,
                               List<Ref> collectius, List<Contacte> contactes, List<Horari> horaris,
                               List<Prestacio> prestacions) {}

    public record CentreDetall(long id, String codi, String nom, Ref tipusCentre, Ref municipi, String adreca,
                               String codiPostal, Double latitud, Double longitud, String precisioPunt, Font fontPunt,
                               String imatge, Ref titular, Ref gestor, Font font, List<Contacte> contactes,
                               List<Horari> horaris, List<ServeiResum> serveis) {}

    public record EntitatResum(long id, String codi, String nom, Ref formaJuridica, String sector, Ref municipi) {}

    public record EntitatDetall(long id, String codi, String nom, Ref formaJuridica, String sector, String adreca,
                                Ref municipi, String codiPostal, Font font, List<Contacte> contactes,
                                List<Horari> horaris, List<ServeiResum> serveisPrestats,
                                List<CentreResum> centresTitulats, List<CentreResum> centresGestionats) {}

    public record Error(String error) {}
}
