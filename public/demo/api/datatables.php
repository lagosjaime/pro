<?php

declare(strict_types=1);

use Dotenv\Dotenv;

$root = dirname(__DIR__, 3);

require $root . '/vendor/autoload.php';

if (is_file($root . '/.env')) {
    Dotenv::createImmutable($root)->safeLoad();
}

/**
 * Datasets habilitados para DataTables (server-side processing).
 *
 * La clave es el valor que viaja en el request (campo "dataset"). La tabla y
 * las columnas SIEMPRE salen de esta lista: los nombres de columna que envía
 * el cliente solo se usan para elegir de esta lista, nunca se interpolan en la
 * consulta. Agrega aqui los datasets de tus modulos.
 */
$datasets = [
    'usuarios' => [
        'table' => 'demo_usuarios',
        'columns' => ['id', 'nombre', 'email', 'rol', 'created_at'],
    ],
];

header('Content-Type: application/json; charset=utf-8');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
    http_response_code(405);
    header('Allow: POST');
    exit(json_encode(['error' => 'Metodo no permitido, usa POST']));
}

$post = static fn (string $key, mixed $default = null): mixed => $_POST[$key] ?? $default;

$dataset = (string) $post('dataset', '');

if (!isset($datasets[$dataset])) {
    http_response_code(400);
    exit(json_encode(['error' => 'Dataset desconocido']));
}

$table = $datasets[$dataset]['table'];
$columns = $datasets[$dataset]['columns'];

try {
    $dsn = sprintf(
        'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        getenv('DB_HOST') ?: 'mysql',
        getenv('DB_PORT') ?: '3306',
        getenv('DB_DATABASE') ?: 'pr_db'
    );

    $pdo = new PDO($dsn, getenv('DB_USERNAME') ?: 'pr', getenv('DB_PASSWORD') ?: '', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    exit(json_encode(['error' => 'Error de conexion: ' . $e->getMessage()]));
}

$draw = (int) $post('draw', 0);
$start = max(0, (int) $post('start', 0));
$length = (int) $post('length', 10);
$length = ($length < 1 || $length > 500) ? 10 : $length;

$searchValue = trim((string) (is_array($_POST['search'] ?? null) ? ($_POST['search']['value'] ?? '') : ($_POST['search'] ?? '')));

$where = [];
$params = [];

if ($searchValue !== '') {
    $or = [];
    foreach ($columns as $i => $column) {
        $or[] = "`$column` LIKE :search_$i";
        $params["search_$i"] = '%' . $searchValue . '%';
    }
    $where[] = '(' . implode(' OR ', $or) . ')';
}

$whereSql = $where !== [] ? 'WHERE ' . implode(' AND ', $where) : '';

$orderSql = '';
foreach ((array) ($_POST['order'] ?? []) as $order) {
    $index = (int) ($order['column'] ?? -1);
    $direction = strtoupper((string) ($order['dir'] ?? 'asc')) === 'DESC' ? 'DESC' : 'ASC';

    if (isset($columns[$index])) {
        $orderSql = sprintf('ORDER BY `%s` %s', $columns[$index], $direction);
        break;
    }
}

if ($orderSql === '') {
    $orderSql = sprintf('ORDER BY `%s` ASC', $columns[0]);
}

$recordsTotal = (int) $pdo->query("SELECT COUNT(*) FROM `$table`")->fetchColumn();

$stmt = $pdo->prepare("SELECT COUNT(*) FROM `$table` $whereSql");
$stmt->execute($params);
$recordsFiltered = (int) $stmt->fetchColumn();

$stmt = $pdo->prepare(sprintf('SELECT * FROM `%s` %s %s LIMIT %d OFFSET %d', $table, $whereSql, $orderSql, $length, $start));
$stmt->execute($params);
$rows = $stmt->fetchAll();

exit(json_encode([
    'draw' => $draw,
    'recordsTotal' => $recordsTotal,
    'recordsFiltered' => $recordsFiltered,
    'data' => $rows,
], JSON_UNESCAPED_UNICODE));
