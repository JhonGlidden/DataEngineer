
---------------------------------------------------------------------------------------------------
---------------------------------- PREGUNTA 1 -----------------------------------------------------
---------------------------------------------------------------------------------------------------
WITH RankedCampaigns AS (
    SELECT
        c.[NOMBRE CAMPAÑA],
        u.[REGIÓN],
        SUM(l.LEADS) AS TotalLeads,
        ROW_NUMBER() OVER(PARTITION BY u.[REGIÓN] ORDER BY SUM(l.LEADS) DESC) AS rnk
    FROM [Tabla de LEADS] l
    JOIN [Tabla de Ubicaciones] u ON l.[Id_CAMPAÑA] = u.[Id_CAMPAÑA] AND l.FECHA = u.FECHA
    JOIN [Tabla de Campañas] c ON l.[Id_CAMPAÑA] = c.[Id_CAMPAÑA]
    WHERE u.FECHA BETWEEN DATEADD(YEAR, -1, GETDATE()) AND GETDATE() -- Último año desde la fecha actual
    GROUP BY c.[NOMBRE CAMPAÑA], u.[REGIÓN]
)

SELECT [NOMBRE CAMPAÑA], [REGIÓN], TotalLeads
FROM RankedCampaigns
WHERE rnk <= 3
ORDER BY [REGIÓN], rnk;

---------------------------------------------------------------------------------------------------
---------------------------------- PREGUNTA 2 -----------------------------------------------------
---------------------------------------------------------------------------------------------------
WITH LeadsPerTrimester AS (
    SELECT
        c.[NOMBRE CAMPAÑA],
        YEAR(l.FECHA) AS Anio,
        DATEPART(QUARTER, l.FECHA) AS Cuarto,
        SUM(l.LEADS) AS TotalLeads
    FROM [Tabla de Campañas] c
    JOIN [Tabla de LEADS] l ON c.[Id_CAMPAÑA] = l.[Id_CAMPAÑA]
    WHERE 
	-- Condición para tomar en cuenta solo los últimos 4 trimestres (este año y el anterior)
        l.FECHA >= DATEADD(YEAR, -1, GETDATE())
    GROUP BY c.[NOMBRE CAMPAÑA], YEAR(l.FECHA), DATEPART(QUARTER, l.FECHA)
),
LagData AS (
    SELECT
        [NOMBRE CAMPAÑA],
        Anio,
        Cuarto,
        TotalLeads,
        LAG(TotalLeads) OVER(PARTITION BY [NOMBRE CAMPAÑA] ORDER BY Year, Quarter) AS LastYearTotalLeads
    FROM LeadsPerTrimester
)

SELECT TOP 5
    [NOMBRE CAMPAÑA],
	-- PercentageGrowth tendrá NULL para aquellas campañas que no tuvieron LEADS en el trimestre del año anterior
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
    ID_CAMPAÑA INT,
    MES VARCHAR(50),
    AÑO INT,
    TOTAL_IMPR INT,
    CPM_MEAN DECIMAL(10, 2)
);

CREATE PROCEDURE sp_ResumenImpresionesMensuales AS
BEGIN
    -- Asegurarse de eliminar las filas previas del último año en la tabla resumen.
    DELETE FROM prod.resumen_impr_mensual
    WHERE DATEFROMPARTS(AÑO, MONTH('01/'+MES+'/2023'), 1) BETWEEN DATEADD(YEAR, -1, GETDATE()) AND GETDATE();

    -- Insertar los nuevos registros
    INSERT INTO prod.resumen_impr_mensual
    SELECT 
        ID_CAMPAÑA,
        DATENAME(MONTH, Fecha) AS MES,
        YEAR(Fecha) AS AÑO,
        SUM(Impression) AS TOTAL_IMPR,
        AVG(CPM) AS CPM_MEAN
    FROM tmp.impression
    WHERE Fecha BETWEEN DATEADD(YEAR, -1, GETDATE()) AND GETDATE()
    GROUP BY ID_CAMPAÑA, DATENAME(MONTH, Fecha), YEAR(Fecha);
    
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
    INSERT INTO prod.leads_diaria (FECHA, PLATAFORMA, Nombre_Campaña, Leads)
    SELECT 
        CAST(Hora AS DATE) AS FECHA,
        LEFT(Campaña, CHARINDEX(' ', Campaña) - 1) AS PLATAFORMA,
        RIGHT(Campaña, LEN(Campaña) - CHARINDEX(' ', Campaña)) AS Nombre_Campaña,
        SUM(Leads) AS Leads
    FROM 
        tmp.leads_hora
    WHERE 
        CAST(Hora AS DATE) = CAST(GETDATE() AS DATE)
    GROUP BY 
        CAST(Hora AS DATE),
        LEFT(Campaña, CHARINDEX(' ', Campaña) - 1),
        RIGHT(Campaña, LEN(Campaña) - CHARINDEX(' ', Campaña));
END;

EXEC sp_AcumularLeadsDiarios;
