DECLARE @MergeOutput TABLE (
    ActionType NVARCHAR(10),
    Col1 INT,
    -- otros campos según sea necesario
);

-- merge es una operacion de 
MERGE TargetTable AS target
USING SourceTable AS source
ON target.KeyColumn = source.KeyColumn
WHEN MATCHED THEN
    UPDATE SET target.Col1 = source.Col1
WHEN NOT MATCHED BY TARGET THEN
    INSERT (Col1, Col2) VALUES (source.Col1, source.Col2)
WHEN NOT MATCHED BY SOURCE THEN
    DELETE
OUTPUT $action, inserted.Col1 INTO @MergeOutput;

-- Verificar si se realizaron operaciones
IF EXISTS (SELECT 1 FROM @MergeOutput)
BEGIN
    -- Se realizaron operaciones
END
ELSE
BEGIN
    -- No se realizaron operaciones
END



-- ejemplo de uso
-- syncronizacion de clientes de una base de datos de SAP para servicio externo

DECLARE @data = '[
  {
    "id_empresa": 1,
    "cardcode": "ABCD1234",
    "cardname": "PLAYA MAROMA INMUEBLES",
    "address": "CARRET.FEDERAL LIBRE CANCUN",
    "zipcode": "77712",
    "city": "PLAYA DEL CARMEN",
    "country": "MX",
    "e_mail": "fe.semrc@example.com,compras.semrc@example.com,almacen.semrc@example.com",
    "cardfname": "SECRETS",
    "shiptodef": "SECRETS",
    "projectcod": "SECRET",
    "alias": "EXAMPLE_ALIAS",
    "listnum": 37,
    "id_vendedor": 2,
    "cod_almacen": "CUN"
  },
  {
    "id_empresa": 1,
    "cardcode": "ABCD1234",
    "cardname": "MOSQUITOS HOSPITALITY GROUP",
    "address": "AVENIDA PASEO DE LA REFORMA",
    "zipcode": "11950",
    "city": "CIUDAD DE MEXICO",
    "country": "MX",
    "e_mail": "ap.playa@example.com",
    "cardfname": "THOMPSON PLAYA",
    "shiptodef": "THOMPSON",
    "projectcod": "THOMPSON",
    "alias": "MOSQUITOS HOSPITALITY GROUP",
    "listnum": 12,
    "id_vendedor": 1,
    "cod_almacen": "CUN"
  }
]'
CREATE PROCEDURE [dbo].[sp_web_BulkInsertOrUpdateClients] @data NVARCHAR(MAX)
AS
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @clients TABLE
                     (
                         cardcode      NVARCHAR(60),
                         cardname      NVARCHAR(255),
                         nombre        NVARCHAR(255),
                         usuario       NVARCHAR(120),
                         password      NVARCHAR(255),
                         email         NVARCHAR(MAX),
                         alias         NVARCHAR(255),
                         direccion_1   NVARCHAR(255),
                         codigo_postal NVARCHAR(15),
                         ciudad        NVARCHAR(255),
                         pais          NVARCHAR(255),
                         id_empresa    INT,
                         priceList     INT,
                         sellerId      INT,
                         warehouseCode NVARCHAR(50)
                     )

    INSERT INTO @clients
    SELECT cardcode,
           cardname,
           nombre,
           usuario,
           password,
           email,
           alias,
           direccion_1,
           codigo_postal,
           ciudad,
           pais,
           id_empresa,
           priceList,
           sellerId,
           warehouseCode
    FROM OPENJSON(@data)
                  WITH (
                      cardcode NVARCHAR(60) '$.cardcode',
                      cardname NVARCHAR(255) '$.cardname',
                      nombre NVARCHAR(255) '$.name',
                      usuario NVARCHAR(120) '$.username',
                      password NVARCHAR(255) '$.password',
                      email NVARCHAR(MAX) '$.email',
                      alias NVARCHAR(255) '$.alias',
                      direccion_1 NVARCHAR(255) '$.address',
                      codigo_postal NVARCHAR(15) '$.zipcode',
                      ciudad NVARCHAR(255) '$.city',
                      pais NVARCHAR(255) '$.country',
                      id_empresa INT '$.companyId',
                      priceList INT '$.priceList',
                      sellerId INT '$.sellerId',
                      warehouseCode NVARCHAR(50) '$.warehouseCode'
                      )

    MERGE INTO clientes AS target
    USING @clients AS source
    ON target.cardcode = source.cardcode AND target.id_empresa = source.id_empresa
    WHEN MATCHED THEN
        UPDATE
        SET target.cardname            = source.cardname,
            target.email               = source.email,
            target.alias               = source.alias,
            target.direccion_1         = source.direccion_1,
            target.codigo_postal       = source.codigo_postal,
            target.ciudad              = source.ciudad,
            target.pais                = source.pais,
            target.id_lista_precio_sap = source.priceList,
            target.id_vendedor_sap     = IIF(source.sellerId < 0, NULL, source.sellerId)
    WHEN NOT MATCHED THEN
        INSERT (cardname,
                email,
                alias,
                direccion_1,
                codigo_postal,
                ciudad,
                pais,
                id_lista_precio_sap,
                id_vendedor_sap,
                id_empresa,
                cardcode)
        VALUES (source.cardname,
                source.email,
                source.alias,
                source.direccion_1,
                source.codigo_postal,
                source.ciudad,
                source.pais,
                source.priceList,
                IIF(source.sellerId < 1, NULL, source.sellerId),
                source.id_empresa,
                source.cardcode);

    MERGE INTO usuarios AS trg
    USING @clients AS src
    ON trg.usuario = src.usuario
    WHEN MATCHED THEN -- si la causula ON se cumple
        UPDATE
        SET trg.nombre     = src.nombre,
            trg.id_cliente = ISNULL((SELECT TOP (1) id_cliente
                                     FROM clientes c
                                     WHERE c.cardcode = src.cardcode
                                       AND c.id_empresa = src.id_empresa), trg.id_cliente)
    WHEN NOT MATCHED THEN
        INSERT (nombre, usuario, password, vigencia_password, activo, id_perfil, id_tipo_usuario, id_empresa,
                id_cliente)
        VALUES (src.nombre, src.usuario, src.password, DATEADD(HOUR, -5, GETUTCDATE()), 1, 1, 1,
                src.id_empresa, (SELECT TOP (1) id_cliente
                                 FROM clientes c
                                 WHERE c.cardcode = src.cardcode
                                   AND c.id_empresa = src.id_empresa));

    MERGE INTO usuarios_almacen trg
    USING (SELECT DISTINCT u.id_usuario, a.id_almacen AS id_almacen
           FROM usuarios u
                    INNER JOIN clientes cl ON cl.id_cliente = u.id_cliente
                    INNER JOIN @clients c ON c.id_empresa = u.id_empresa AND c.cardcode = cl.cardcode
                    INNER JOIN almacen a ON a.clave_sap = c.warehouseCode AND a.id_empresa = cl.id_empresa
           WHERE id_almacen IS NOT NULL) src
    ON trg.id_usuario = src.id_usuario
    WHEN MATCHED THEN
        UPDATE SET trg.id_almacen = src.id_almacen
    WHEN NOT MATCHED THEN
        INSERT (id_usuario, id_almacen) VALUES (src.id_usuario, src.id_almacen);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION
    INSERT INTO errores_web (message, timestamp) VALUES (@ErrorMessage, dbo.fn_getCurrentDate());
    SELECT @ErrorMessage AS error;
END CATCH
GO

