/*═══════════════════════════════════════════════════════════════════════════
  Paridad de ESCRITURA — fingerprint de estado de la BD (antes/después)
  ---------------------------------------------------------------------------
  Herramienta de validación de la REGLA MÁXIMA: "todo SP debe ser INDISTINGUIBLE
  de SAE por GUI". Es el equivalente-de-escritura de la paridad EXCEPT de lecturas.

  Toma una "huella" de TODAS las tablas de usuario de la BD: (tabla, #filas,
  checksum_agg). Se corre ANTES y DESPUÉS de una operación (en la GUI de SAE, o de
  un SP) con etiquetas distintas; el diff de huellas revela EXACTAMENTE qué tablas
  cambiaron — incluidas las que uno no anticipó (la red de seguridad).

  Uso:
    -- 1) antes de la operación:
    EXEC dbo.__FingerprintTomar @Etiqueta='gui_antes';
    -- 2) (hacer la operación en la GUI de SAE, o correr el SP)
    -- 3) después:
    EXEC dbo.__FingerprintTomar @Etiqueta='gui_despues';
    -- 4) ver qué tablas cambiaron:
    EXEC dbo.__FingerprintDiff @A='gui_antes', @B='gui_despues';

  Vive en la BD del SANDBOX (objetos __-prefijados, descartables). NO es un SP del
  puerto (no va a producción); es andamiaje de validación.
═══════════════════════════════════════════════════════════════════════════*/
IF OBJECT_ID('dbo.__Fingerprint') IS NULL
    CREATE TABLE dbo.__Fingerprint (
        Etiqueta   varchar(50)  NOT NULL,
        Tabla      nvarchar(300) NOT NULL,
        Filas      bigint       NOT NULL,
        Checksum   bigint       NULL,
        TomadoUtc  datetime2    NOT NULL CONSTRAINT DF___fp_utc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK___fp PRIMARY KEY (Etiqueta, Tabla)
    );
GO
CREATE OR ALTER PROCEDURE dbo.__FingerprintTomar @Etiqueta varchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.__Fingerprint WHERE Etiqueta=@Etiqueta;

    DECLARE @sql nvarchar(max) = N'';
    -- Para cada tabla de usuario: #filas + CHECKSUM_AGG(BINARY_CHECKSUM(*)) (ignora
    -- el orden físico; detecta inserciones, borrados y cambios de columna).
    SELECT @sql = @sql + N'
        INSERT INTO dbo.__Fingerprint (Etiqueta, Tabla, Filas, Checksum)
        SELECT ' + QUOTENAME(@Etiqueta,'''') + N', ' + QUOTENAME(s.name+N'.'+t.name,'''') + N',
               COUNT_BIG(*), CHECKSUM_AGG(BINARY_CHECKSUM(*))
        FROM ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) + N' WITH (NOLOCK);'
    FROM sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE t.is_ms_shipped = 0 AND t.name <> '__Fingerprint';

    EXEC sys.sp_executesql @sql;
END
GO
CREATE OR ALTER PROCEDURE dbo.__FingerprintDiff @A varchar(50), @B varchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    -- Tablas donde cambió #filas o checksum entre las dos huellas (o que aparecen/desaparecen).
    SELECT
        Tabla        = COALESCE(a.Tabla, b.Tabla),
        FilasAntes   = a.Filas,
        FilasDespues = b.Filas,
        DeltaFilas   = COALESCE(b.Filas,0) - COALESCE(a.Filas,0),
        ChecksumCambio = CASE WHEN COALESCE(a.Checksum,-999999) <> COALESCE(b.Checksum,-999999) THEN 'SI' ELSE 'no' END
    FROM (SELECT * FROM dbo.__Fingerprint WHERE Etiqueta=@A) a
    FULL OUTER JOIN (SELECT * FROM dbo.__Fingerprint WHERE Etiqueta=@B) b ON a.Tabla=b.Tabla
    WHERE COALESCE(a.Filas,-1) <> COALESCE(b.Filas,-1)
       OR COALESCE(a.Checksum,-999999) <> COALESCE(b.Checksum,-999999)
    ORDER BY ABS(COALESCE(b.Filas,0) - COALESCE(a.Filas,0)) DESC, Tabla;
END
GO
