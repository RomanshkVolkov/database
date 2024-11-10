-- la principal ventaja de esta implementacion fue reducir el trafico de red disminuyendo la complejidad en el cliente
-- y asu vez aprovechar los indices de la base de datos para reducir los tiempos de carga
-- terminando en 300 ms aproximadamente segun la consola en el IDE DATAGRIP


CREATE PROCEDURE [dbo].[sp_web_GetOrders] @companyId INT = 0,
                                          @from NVARCHAR(10) = NULL,
                                          @to NVARCHAR(10) = NULL,
                                          @userId INT = NULL,
                                          @search NVARCHAR(300) = NULL,
                                          @itemsPerPage INT = 16,
                                          @page INT = 1,
                                          @orderByColumn NVARCHAR(128) = NULL,
                                          @orderDirection NVARCHAR(10) = 'ASC',
                                          @skipPagination BIT = 0
AS
BEGIN
    DECLARE @offset INT = (@page - 1) * @itemsPerPage, @sql NVARCHAR(MAX), @currentDate DATE = CAST(dbo.fn_getCurrentDate() AS DATE), @notDateValidation BIT = 0;

    IF (@from IS NULL OR @to IS NULL)
        BEGIN
            SET @notDateValidation = 1;
        END

    IF (@orderDirection <> 'ASC' AND @orderDirection <> 'DESC')
        BEGIN
        -- como el orden de ordenamiento es de los parametros al final de nuestra consulta hacemos una simple comparacion de dos valores posibles
            PRINT 'ERROR';
            THROW 50000, N'Campo invalido prevención de injecciones SQL', 1;
        END
        
    -- definicion de la vista de la tabla final usamos los nombres que queremos ver en la vista
    CREATE TABLE #data
    (
        id                NVARCHAR(50),
        [N° Pedido]       NVARCHAR(20),
        [Almacén]         NVARCHAR(20),
        [Fecha]           NVARCHAR(10),
        [Número de orden] NVARCHAR(100),
        [Cliente]         NVARCHAR(255),
        [N° Entregas]     INT,
        [Creado por]      NVARCHAR(255),
        search_index      NVARCHAR(MAX)
    )

-- logica de obtencion de datos usando el from y el to como se disponga para filtro por rango de fechas
    INSERT INTO #data (id, [N° Pedido], Almacén, Fecha, [Número de orden], Cliente, [Creado por])
    SELECT pds.id_pedido id,
           CONCAT('# ', pds.id_pedido),
           CONCAT(e.prefijo, ' - ', a.clave_sap),
           dbo.fn_formatDateES(pds.fecha),
           pds.num_pedido,
           CONCAT(c.cardcode, ' - ', cd.direccion, ' ', '(', ISNULL(cd.project, 'Default'), ')'),
           u.nombre
    FROM pedidos pds
             INNER JOIN plan_entregas pe ON pds.id_pedido = pe.id_pedido AND
                                            ((@companyId IS NULL OR @companyId = 0) OR pds.id_empresa = @companyId)
        -- if @from and @to params is null check status not 2,3,8 or if the order has been shipped with no more than 200 minutes sent
        AND (
                                                dbo.fn_validateFilterDateFromTo(@from, @to, pds.fecha) = 1
                                                )
        AND (
                                                pe.id_estado NOT IN (3)
                                                )
        AND (
                                                @notDateValidation = 0 OR pe.id_estado <> 2 OR (pe.id_estado = 2 AND
                                                                                                CAST(pds.fecha AS DATE) =
                                                                                                CAST(dbo.fn_getCurrentDate() AS DATE))
                                                )
             INNER JOIN clientes_direcciones cd ON cd.id_direccion = pds.id_direccion
             INNER JOIN clientes c ON pds.id_cliente = c.id_cliente
             INNER JOIN usuarios u ON pds.id_usuario = u.id_usuario
             LEFT JOIN almacen a ON a.id_almacen = pds.id_almacen
             INNER JOIN empresas e ON e.id_empresa = c.id_empresa
    GROUP BY pds.id_pedido, e.prefijo, a.clave_sap, pds.fecha, pds.num_pedido, u.nombre, c.cardcode, c.cardname,
             cd.direccion, cd.project;

    -- construimos un indice de busqueda
    -- esto lo logramos concatenando todos los campos de interes en una columna
    UPDATE d
    SET d.search_index  = CONCAT(d.[N° Pedido], ' ', d.[N° Pedido], ' ', d.[Almacén], ' ', d.[Fecha], ' ',
                                 d.[Número de orden], ' ', d.[N° Entregas], ' ', d.[Creado por]),
        d.id            = CONCAT(d.id, '?type=order'), -- necesary type for query param to open modal
        d.[N° Entregas] = pe.qn
    FROM #data d
             INNER JOIN (SELECT id_pedido, COUNT(id_plan_entrega) qn
                         FROM plan_entregas
                         WHERE id_estado <> 3
                         GROUP BY id_pedido) pe ON CAST(d.id AS INT) = pe.id_pedido;

    -- si tenemos un campo de busqueda @search eliminamos los datos ya filtrados por fecha que no coincidan con un criterio de busqueda
    DELETE #data WHERE (@search IS NOT NULL AND @search <> '') AND search_index NOT LIKE CONCAT('%', @search, '%');
    
    -- eliminamos el indice de busqueda para que no salga en nuestra tabla
    ALTER TABLE #data
        DROP COLUMN search_index;
    
    -- 
    SET @sql = 'SELECT *, ' +
               'dbo.fn_calculatepaginationpages(COUNT(*) OVER (), @itemsPerPage) totalPages,' +
               '@page page,' +
               '@itemsPerPage itemsPerPage,' +
               'COUNT(*) OVER () totalItems ' +
               'FROM #data ';

    IF (@orderByColumn IS NOT NULL)
        BEGIN
            IF (CHARINDEX('fecha', @orderByColumn) > 0)
                BEGIN
                    SET @sql =
                            @sql + N'ORDER BY CONVERT(DATE, ' + QUOTENAME(@orderByColumn) + ', 103) ' +
                            @orderDirection + ' ';
                END
            ELSE
                SET @sql =
                        @sql + N'ORDER BY dbo.fn_UnifyKey(' + QUOTENAME(@orderByColumn) + ') ' + @orderDirection + ' ';
        END
    ELSE
        BEGIN
            SET @sql = @sql + N'ORDER BY dbo.fn_clearId(' + QUOTENAME('id') + ') DESC, CONVERT(DATE, ' +
                       QUOTENAME('Fecha') +
                       ', 103) DESC ';
        END

    IF @skipPagination = 0
        BEGIN
            SET @sql = @sql + N'OFFSET ' + CAST(@offset AS NVARCHAR(10)) + ' ROWS FETCH NEXT ' +
                       CAST(@itemsPerPage AS NVARCHAR(10)) + ' ROWS ONLY ';
        END
     --PRINT @sql;
    EXEC sp_executesql @sql, N'@itemsPerPage INT, @page INT', @itemsPerPage, @page;
END
GO

