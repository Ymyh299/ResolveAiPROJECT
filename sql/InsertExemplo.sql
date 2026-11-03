-- =====================================================================
-- INSERTS DE TESTE - resolveaidb
-- Rodar DEPOIS do script de criação (banco vazio, para os IDs baterem).
-- =====================================================================
USE resolveaidb;
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- VALORES DOS CAMPOS DE TEXTO (ENUMs do app)
-- Valores conferidos com o código Dart. Para mudar, altere SÓ AQUI.
-- ---------------------------------------------------------------------
-- tipo_usuario (usuario.dart)
SET @tu_admin       = 'administrador';
SET @tu_gestor      = 'administrador';
SET @tu_executor    = 'comum';
SET @tu_solicitante = 'comum';
-- estado_conservacao (patrimonio.dart)
SET @ec_otimo   = 'Novo';
SET @ec_bom     = 'Bom';
SET @ec_regular = 'Regular';
SET @ec_ruim    = 'Ruim';
SET @ec_irrec   = 'Irrecuperável';
-- prioridade (ordemdeservico.dart)
SET @pr_baixa   = 'Baixa';
SET @pr_media   = 'Média';
SET @pr_alta    = 'Alta';
SET @pr_urgente = 'Urgente';
-- status (ordemdeservico.dart)
SET @st_aberta    = 'Aberta';
SET @st_andamento = 'Em andamento';
SET @st_concluida = 'Concluída';
SET @st_cancelada = 'Cancelada';
-- tipo_manutencao (ordemdeservico.dart) - só existem Corretiva e Preventiva
SET @tm_preventiva = 'Preventiva';
SET @tm_corretiva  = 'Corretiva';

-- ---------------------------------------------------------------------
-- SETOR (ids 1-5)
-- ---------------------------------------------------------------------
INSERT INTO SETOR (nome, descricao) VALUES
('Manutenção',     'Reparos elétricos, hidráulicos e de equipamentos do clube'),
('Limpeza',        'Limpeza e conservação das áreas internas e externas'),
('Administrativo', 'Gestão, secretaria e financeiro'),
('Esportes',       'Quadras, academia e atividades esportivas'),
('Área Aquática',  'Piscinas, vestiários e áreas molhadas');

-- ---------------------------------------------------------------------
-- USUARIO (ids 1-8)
-- ATENÇÃO: a senha abaixo é SHA2 de '123456'. Se o app usa bcrypt/argon2,
-- o login desses usuários não vai funcionar: troque pelo hash gerado pelo app.
-- ---------------------------------------------------------------------
INSERT INTO USUARIO (nome, cpf, telefone, email, senha, tipo_usuario, SETOR_idSETOR) VALUES
('Carlos Eduardo Lima',   '111.111.111-11', '(35) 99111-1111', 'admin@resolveai.com',       SHA2('123456',256), @tu_admin,       3),
('Marina Souza Alves',    '222.222.222-22', '(35) 99222-2222', 'marina.gestora@clube.com',  SHA2('123456',256), @tu_gestor,      1),
('João Pedro Ribeiro',    '333.333.333-33', '(35) 99333-3333', 'joao.exec@clube.com',       SHA2('123456',256), @tu_executor,    1),
('Rafael Mendes Costa',   '444.444.444-44', '(35) 99444-4444', 'rafael.exec@clube.com',     SHA2('123456',256), @tu_executor,    1),
('Ana Paula Ferreira',    '555.555.555-55', '(35) 99555-5555', 'ana.limpeza@clube.com',     SHA2('123456',256), @tu_executor,    2),
('Lucas Martins Rocha',   '666.666.666-66', '(35) 99666-6666', 'lucas.esportes@clube.com',  SHA2('123456',256), @tu_solicitante, 4),
('Juliana Teixeira Dias', '777.777.777-77', '(35) 99777-7777', 'juliana.piscina@clube.com', SHA2('123456',256), @tu_solicitante, 5),
('Fernanda Oliveira Reis','888.888.888-88', '(35) 99888-8888', 'fernanda.adm@clube.com',     SHA2('123456',256), @tu_solicitante, 3);

-- ---------------------------------------------------------------------
-- LOCALIZACAO (ids 1-10, com hierarquia pai/filho)
-- ---------------------------------------------------------------------
INSERT INTO LOCALIZACAO (nome_localizacao, LOCALIZACAO_idPAI) VALUES
('Clube',                NULL),  -- 1
('Bloco Esportivo',      1),     -- 2
('Quadra Poliesportiva', 2),     -- 3
('Área Aquática',        1),     -- 4
('Piscina Adulto',       4),     -- 5
('Vestiário Masculino',  4),     -- 6
('Sede Social',          1),     -- 7
('Salão de Festas',      7),     -- 8
('Cozinha',              8),     -- 9
('Academia',             2);     -- 10

-- ---------------------------------------------------------------------
-- PATRIMONIO (ids 1-8)
-- ---------------------------------------------------------------------
INSERT INTO PATRIMONIO (nome, valor, descricao, estado_conservacao, data_compra, LOCALIZACAO_idLOCALIZACAO) VALUES
('Bomba da piscina adulto',   4800.00,  'Motobomba 3 CV para filtragem',          @ec_regular, '2020-03-15', 5),  -- 1
('Ar-condicionado split 36k', 6200.00,  'Split inverter do salão de festas',      @ec_bom,     '2022-08-10', 8),  -- 2
('Refletor LED da quadra',    1350.00,  'Refletor 400W lado norte',               @ec_regular, '2021-05-20', 3),  -- 3
('Esteira profissional',      12500.00, 'Esteira elétrica da academia',           @ec_bom,     '2023-01-12', 10), -- 4
('Fogão industrial 6 bocas',  3900.00,  'Fogão da cozinha do salão',              @ec_regular, '2019-11-05', 9),  -- 5
('Chuveiro elétrico',         320.00,   'Chuveiro do vestiário masculino',        @ec_ruim,    '2022-02-18', 6),  -- 6
('Freezer horizontal 500L',   4100.00,  'Freezer da cozinha',                     @ec_otimo,   '2024-04-30', 9),  -- 7
('Bebedouro industrial',      1850.00,  'Bebedouro do bloco esportivo',           @ec_bom,     '2023-09-08', 2);  -- 8

-- ---------------------------------------------------------------------
-- MATERIAL (ids 1-10)
-- ---------------------------------------------------------------------
INSERT INTO MATERIAL (nome, quantidade, data_compra, valor_material) VALUES
('Lâmpada LED 150W',          12.00,  '2026-09-01', 89.90),   -- 1
('Selo mecânico para bomba',   3.00,  '2026-09-15', 245.00),  -- 2
('Fita veda rosca',           40.00,  '2026-08-20', 6.50),    -- 3
('Detergente neutro (L)',     60.00,  '2026-10-01', 12.80),   -- 4
('Desinfetante (L)',          45.00,  '2026-10-01', 15.90),   -- 5
('Saco de lixo 100L (un)',   300.00,  '2026-10-05', 1.20),    -- 6
('Resistência de chuveiro',   10.00,  '2026-09-25', 38.00),   -- 7
('Correia de esteira',         2.00,  '2026-10-10', 120.00),  -- 8
('Lubrificante silicone',      6.00,  '2026-10-10', 29.90),   -- 9
('Cabo flexível 2,5mm (m)',  100.00,  '2026-08-12', 4.50);    -- 10

-- ---------------------------------------------------------------------
-- ORDEMSERVICO (ids 1-12)
-- Colunas: titulo, obs, abertura, inicio, fim, prazo, prioridade, status,
-- tipo, recorrente, intervalo, duracao, proxima, solicitante, executor,
-- setor, localizacao, patrimonio
-- ---------------------------------------------------------------------
INSERT INTO ORDEMSERVICO
(titulo_os, observacao, data_abertura, data_inicio, data_fim, prazo_previsto, prioridade, status, tipo_manutencao,
 recorrente, intervalo_dias, duracao_dias, proxima_data,
 USUARIO_idSolicitante, USUARIO_idExecutor, SETOR_idSETOR, LOCALIZACAO_idLOCALIZACAO, PATRIMONIO_idPATRIMONIO)
VALUES
('Trocar refletor queimado da quadra', 'Refletor do lado norte apagou durante o treino.',
 '2026-10-01 08:30:00', '2026-10-02 09:00:00', '2026-10-02 11:30:00', '2026-10-05', @pr_media, @st_concluida, @tm_corretiva,
 0, NULL, NULL, NULL, 6, 3, 1, 3, 3),

('Manutenção da bomba da piscina', 'Bomba com vazamento no selo e ruído excessivo.',
 '2026-10-10 07:45:00', '2026-10-12 08:00:00', '2026-10-12 16:00:00', '2026-10-15', @pr_alta, @st_concluida, @tm_corretiva,
 0, NULL, NULL, NULL, 7, 4, 1, 5, 1),

('Limpeza semanal do vestiário masculino', 'Limpeza completa com desinfecção.',
 '2026-10-15 16:00:00', '2026-10-16 06:00:00', '2026-10-16 08:00:00', '2026-10-16', @pr_baixa, @st_concluida, @tm_preventiva,
 1, 7, 1, '2026-11-06', 7, 5, 2, 6, NULL),

('Revisão preventiva do ar-condicionado', 'Limpeza de filtros e checagem de gás.',
 '2026-10-20 10:00:00', NULL, NULL, '2026-11-10', @pr_media, @st_aberta, @tm_preventiva,
 1, 90, 1, '2026-11-10', 8, NULL, 1, 8, 2),

('Esteira com ruído na correia', 'Barulho forte ao operar acima de 8 km/h.',
 '2026-10-25 09:20:00', '2026-11-02 14:00:00', NULL, '2026-11-06', @pr_alta, @st_andamento, @tm_corretiva,
 0, NULL, NULL, NULL, 6, 3, 1, 10, 4),

('Vazamento de gás no fogão industrial', 'Cheiro de gás na boca 3. Interditar até reparo.',
 '2026-10-28 11:10:00', NULL, NULL, '2026-11-04', @pr_urgente, @st_aberta, @tm_corretiva,
 0, NULL, NULL, NULL, 8, NULL, 1, 9, 5),

('Limpeza pós-evento no salão de festas', 'Evento de aniversário no sábado.',
 '2026-11-01 22:00:00', '2026-11-02 08:00:00', '2026-11-02 12:00:00', '2026-11-02', @pr_media, @st_concluida, @tm_corretiva,
 0, NULL, NULL, NULL, 8, 5, 2, 8, NULL),

('Pintura da parede do bloco esportivo', 'Cancelada: pintura será feita em reforma maior.',
 '2026-09-20 15:00:00', NULL, NULL, '2026-10-20', @pr_baixa, @st_cancelada, @tm_corretiva,
 0, NULL, NULL, NULL, 6, NULL, 1, 2, NULL),

('Revisão semestral do freezer', 'Checar termostato e vedação da porta.',
 '2026-10-30 08:00:00', NULL, NULL, '2026-11-15', @pr_baixa, @st_aberta, @tm_preventiva,
 1, 180, 1, '2026-11-15', 8, NULL, 1, 9, 7),

('Limpeza diária da piscina', 'Limpeza de bordas, peneiração e checagem de cloro.',
 '2026-11-01 07:00:00', '2026-11-03 06:00:00', NULL, '2026-11-03', @pr_media, @st_andamento, @tm_preventiva,
 1, 1, 1, '2026-11-04', 7, 5, 2, 5, NULL),

('Troca de resistências dos chuveiros', 'Chuveiros sem aquecer no vestiário masculino.',
 '2026-10-05 13:30:00', '2026-10-06 09:00:00', '2026-10-06 10:30:00', '2026-10-08', @pr_alta, @st_concluida, @tm_corretiva,
 0, NULL, NULL, NULL, 7, 4, 1, 6, 6),

('Bebedouro com baixa pressão de água', 'Possível entupimento no filtro.',
 '2026-11-02 10:15:00', NULL, NULL, '2026-11-09', @pr_media, @st_aberta, @tm_corretiva,
 0, NULL, NULL, NULL, 6, NULL, 1, 2, 8);

-- ---------------------------------------------------------------------
-- ORDEMSERVICO_has_MATERIAL
-- valor_unitario = valor do material no momento do uso
-- ---------------------------------------------------------------------
INSERT INTO ORDEMSERVICO_has_MATERIAL
(ORDEMSERVICO_idORDEMSERVICO, MATERIAL_idMATERIAL, quantidade_usada, valor_unitario, data_uso) VALUES
(1,  1,  1.00,  89.90,  '2026-10-02 10:00:00'),
(1,  10, 5.00,  4.50,   '2026-10-02 10:30:00'),
(2,  2,  1.00,  245.00, '2026-10-12 11:00:00'),
(2,  3,  2.00,  6.50,   '2026-10-12 12:00:00'),
(3,  4,  2.00,  12.80,  '2026-10-16 06:30:00'),
(3,  5,  1.50,  15.90,  '2026-10-16 06:45:00'),
(3,  6,  5.00,  1.20,   '2026-10-16 07:30:00'),
(5,  8,  1.00,  120.00, '2026-11-02 15:00:00'),
(5,  9,  1.00,  29.90,  '2026-11-02 15:30:00'),
(7,  4,  3.00,  12.80,  '2026-11-02 08:30:00'),
(7,  5,  2.00,  15.90,  '2026-11-02 09:00:00'),
(7,  6,  10.00, 1.20,   '2026-11-02 11:00:00'),
(10, 4,  1.00,  12.80,  '2026-11-03 06:30:00'),
(11, 7,  4.00,  38.00,  '2026-10-06 09:30:00'),
(11, 10, 3.00,  4.50,   '2026-10-06 10:00:00');