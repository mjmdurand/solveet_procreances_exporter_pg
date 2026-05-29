SELECT
    numfact,
    NumLignFact,
    SUBSTRING(LIBELLE, 1, 255) AS LIBELLE,
    CodProdFact,
    MtReg,
    MtHonoHT,
    debours,
    totht,
    DatReg,
    CodTva,
    L1PAIEMENT,
    L1QUANTITE
FROM LIG_FACT;
