<?php

declare(strict_types=1);

$db = [
    'host' => getenv('DB_HOST') ?: 'mysql',
    'port' => (int) (getenv('DB_PORT') ?: 3306),
    'name' => getenv('DB_DATABASE') ?: 'pr_db',
    'user' => getenv('DB_USERNAME') ?: 'pr',
    'pass' => getenv('DB_PASSWORD') ?: '',
];

$dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $db['host'], $db['port'], $db['name']);

$dbStatus = 'sin conexion';
$dbVersion = null;

try {
    $pdo = new PDO($dsn, $db['user'], $db['pass'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    $dbStatus = 'conectado';
    $dbVersion = $pdo->query('SELECT VERSION()')->fetchColumn();
} catch (PDOException $e) {
    $dbStatus = 'error: ' . $e->getMessage();
}

?><!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <title><?= htmlspecialchars((string) (getenv('APP_NAME') ?: 'pr')) ?></title>
    <style>
        body { font-family: system-ui, sans-serif; margin: 3rem auto; max-width: 40rem; line-height: 1.6; }
        code { background: #f0f0f0; padding: .1rem .3rem; border-radius: 3px; }
        table { border-collapse: collapse; }
        td { padding: .3rem .8rem .3rem 0; vertical-align: top; }
        .ok { color: #157f3d; }
        .ko { color: #b42318; }
    </style>
</head>
<body>
    <h1><?= htmlspecialchars((string) (getenv('APP_NAME') ?: 'pr')) ?></h1>
    <p>Entorno PHP + nginx + php-fpm + MySQL en Docker.</p>
    <table>
        <tr><td>PHP</td><td><?= htmlspecialchars(PHP_VERSION) ?> (<?= htmlspecialchars(PHP_SAPI) ?>)</td></tr>
        <tr><td>Servidor</td><td><?= htmlspecialchars((string) ($_SERVER['SERVER_SOFTWARE'] ?? 'n/d')) ?></td></tr>
        <tr><td>Usuario</td><td><?= htmlspecialchars(function_exists('posix_geteuid') ? (string) posix_geteuid() : 'n/d') ?></td></tr>
        <tr>
            <td>MySQL</td>
            <td class="<?= $dbVersion ? 'ok' : 'ko' ?>">
                <?= htmlspecialchars($dbStatus) ?>
                <?= $dbVersion ? ' (v' . htmlspecialchars((string) $dbVersion) . ')' : '' ?>
            </td>
        </tr>
    </table>
</body>
</html>
