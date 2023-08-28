
---------------------------------------------------------------------------------------------------
---------------------------------- PREGUNTA 1 -----------------------------------------------------
---------------------------------------------------------------------------------------------------
WITH RankedCampaigns AS (
    SELECT
        c.[NOMBRE CAMPA�A],
        u.[REGI�N],
        SUM(l.LEADS) AS TotalLeads,
        ROW_NUMBER() OVER(PARTITION BY u.[REGI�N] ORDER BY SUM(l.LEADS) DESC) AS rnk
    FROM [Tabla de LEADS] l
    JOIN [Tabla de Ubicaciones] u ON l.[Id_CAMPA�A] = u.[Id_CAMPA�A] AND l.FECHA = u.FECHA
    JOIN [Tabla de Campa�as] c ON l.[Id_CAMPA�A] = c.[Id_CAMPA�A]
    WHERE u.FECHA BETWEEN DATEADD(YEAR, -1, GETDATE()) AND GETDATE() -- �ltimo a�o desde la fecha actual
    GROUP BY c.[NOMBRE CAMPA�A], u.[REGI�N]
)

SELECT [NOMBRE CAMPA�A], [REGI�N], TotalLeads
FROM RankedCampaigns
WHERE rnk <= 3
ORDER BY [REGI�N], rnk;

---------------------------------------------------------------------------------------------------
---------------------------------- PREGUNTA 2 -----------------------------------------------------
---------------------------------------------------------------------------------------------------
WITH LeadsPerTrimester AS (
    SELECT
        c.[NOMBRE CAMPA�A],
        YEAR(l.FECHA) AS Anio,
        DATEPART(QUARTER, l.FECHA) AS Cuarto,
        SUM(l.LEADS) AS TotalLeads
    FROM [Tabla de Campa�as] c
    JOIN [Tabla de LEADS] l ON c.[Id_CAMPA�A] = l.[Id_CAMPA�A]
    WHERE 
	-- Condici�n para tomar en cuenta solo los �ltimos 4 trimestres (este a�o y el anterior)
        l.FECHA >= DATEADD(YEAR, -1, GETDATE())
    GROUP BY c.[NOMBRE CAMPA�A], YEAR(l.FECHA), DATEPART(QUARTER, l.FECHA)
),
LagData AS (
    SELECT
        [NOMBRE CAMPA�A],
        Anio,
        Cuarto,
        TotalLeads,
        LAG(TotalLeads) OVER(PARTITION BY [NOMBRE CAMPA�A] ORDER BY Year, Quarter) AS LastYearTotalLeads
    FROM LeadsPerTrimester
)

SELECT TOP 5
    [NOMBRE CAMPA�A],
	-- PercentageGrowth tendr� NULL para aquellas campa�as que no tuvieron LEADS en el trimestre del a�o anterior
    CASE 
        WHEN LastYearTotalLeads IS NULL THEN NULL
        ELSE (TotalLeads - LastYearTotalLeads) * 100.0 / NULLIF(LastYearTotalLeads, 0) 
    END AS PercentageGrowth,
    CONCAT(Anio, '-Q', Cuarto) AS [Trimestre]
FROM LagData
WHERE Cuarto = DATEPART(QUARTER, GETDATE())
ORDER BY PercentageGrowth DESC;


---------------------------------------------------------------------------------------------------
---------------------------------- PREGUNTA 3 -----------------------------------------------------
---------------------------------------------------------------------------------------------------

CREATE TABLE prod.resumen_impr_mensual (
    ID_CAMPA�A INT,
    MES VARCHAR(50),
    A�O INT,
    TOTAL_IMPR INT,
    CPM_MEAN DECIMAL(10, 2)
);

CREATE PROCEDURE sp_ResumenImpresionesMensuales AS
BEGIN
    -- Asegurarse de eliminar las filas previas del �ltimo a�o en la tabla resumen.
    DELETE FROM prod.resumen_impr_mensual
    WHERE DATEFROMPARTS(A�O, MONTH('01/'+MES+'/2023'), 1) BETWEEN DATEADD(YEAR, -1, GETDATE()) AND GETDATE();

    -- Insertar los nuevos registros
    INSERT INTO prod.resumen_impr_mensual
    SELECT 
        ID_CAMPA�A,
        DATENAME(MONTH, Fecha) AS MES,
        YEAR(Fecha) AS A�O,
        SUM(Impression) AS TOTAL_IMPR,
        AVG(CPM) AS CPM_MEAN
    FROM tmp.impression
    WHERE Fecha BETWEEN DATEADD(YEAR, -1, GETDATE()) AND GETDATE()
    GROUP BY ID_CAMPA�A, DATENAME(MONTH, Fecha), YEAR(Fecha);
    
END

EXEC sp_ResumenImpresionesMensuales;


---------------------------------------------------------------------------------------------------
---------------------------------- PREGUNTA 4 -----------------------------------------------------
---------------------------------------------------------------------------------------------------

CREATE PROCEDURE sp_AcumularLeadsDiarios
AS
BEGIN
    -- Eliminar los datos de la fecha actual de prod.leads_diaria
    DELETE FROM prod.leads_diaria WHERE FECHA = CAST(GETDATE() AS DATE);

    -- Insertar datos agrupados en prod.leads_diaria
    INSERT INTO prod.leads_diaria (FECHA, PLATAFORMA, Nombre_Campa�a, Leads)
    SELECT 
        CAST(Hora AS DATE) AS FECHA,
        LEFT(Campa�a, CHARINDEX(' ', Campa�a) - 1) AS PLATAFORMA,
        RIGHT(Campa�a, LEN(Campa�a) - CHARINDEX(' ', Campa�a)) AS Nombre_Campa�a,
        SUM(Leads) AS Leads
    FROM 
        tmp.leads_hora
    WHERE 
        CAST(Hora AS DATE) = CAST(GETDATE() AS DATE)
    GROUP BY 
        CAST(Hora AS DATE),
        LEFT(Campa�a, CHARINDEX(' ', Campa�a) - 1),
        RIGHT(Campa�a, LEN(Campa�a) - CHARINDEX(' ', Campa�a));
END;

EXEC sp_AcumularLeadsDiarios;
