<?php
// Example PHP Application
header('Content-Type: text/html; charset=UTF-8');

// Simple configuration
$config = [
    'app_name' => 'Example PHP App',
    'version' => '1.0.0',
    'environment' => 'production'
];

// Get some system info
$server_info = [
    'php_version' => phpversion(),
    'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown',
    'document_root' => $_SERVER['DOCUMENT_ROOT'] ?? 'Unknown',
    'server_name' => $_SERVER['SERVER_NAME'] ?? 'Unknown',
    'request_time' => date('Y-m-d H:i:s', $_SERVER['REQUEST_TIME'] ?? time()),
    'https' => isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'Yes' : 'No'
];

// Handle simple routing
$page = $_GET['page'] ?? 'home';

function renderPage($page, $config, $server_info) {
    switch($page) {
        case 'info':
            return renderInfoPage($config, $server_info);
        case 'test':
            return renderTestPage();
        default:
            return renderHomePage($config, $server_info);
    }
}

function renderHomePage($config, $server_info) {
    return '
    <div class="container">
        <h1>🐘 ' . htmlspecialchars($config['app_name']) . '</h1>
        
        <div class="status">
            <h3>✅ PHP Application Running!</h3>
            <p>Your Nix-based PHP web server is working correctly.</p>
        </div>
        
        <div class="info">
            <h3>📊 Server Information</h3>
            <ul>
                <li><strong>PHP Version:</strong> ' . htmlspecialchars($server_info['php_version']) . '</li>
                <li><strong>Server:</strong> ' . htmlspecialchars($server_info['server_software']) . '</li>
                <li><strong>HTTPS:</strong> ' . htmlspecialchars($server_info['https']) . '</li>
                <li><strong>Request Time:</strong> ' . htmlspecialchars($server_info['request_time']) . '</li>
            </ul>
        </div>
        
        <div class="info">
            <h3>🔗 Navigation</h3>
            <p>
                <a href="?page=home" class="btn">Home</a>
                <a href="?page=info" class="btn">PHP Info</a>
                <a href="?page=test" class="btn">Test Features</a>
            </p>
        </div>
        
        <div class="info">
            <h3>🔧 Template Features</h3>
            <ul>
                <li>PHP-FPM with Unix socket</li>
                <li>Nginx reverse proxy</li>
                <li>SSL/TLS termination</li>
                <li>Error logging</li>
                <li>Process management</li>
            </ul>
        </div>
    </div>';
}

function renderInfoPage($config, $server_info) {
    ob_start();
    phpinfo();
    $phpinfo = ob_get_clean();
    
    // Extract just the body content
    preg_match('/<body[^>]*>(.*?)<\/body>/is', $phpinfo, $matches);
    $phpinfo_body = $matches[1] ?? 'PHP Info not available';
    
    return '
    <div class="container">
        <h1>📋 PHP Information</h1>
        <p><a href="?page=home" class="btn">← Back to Home</a></p>
        <div class="phpinfo">' . $phpinfo_body . '</div>
    </div>';
}

function renderTestPage() {
    $tests = [
        'File System' => is_writable('/tmp') ? '✅ Writable' : '❌ Not writable',
        'Session Support' => function_exists('session_start') ? '✅ Available' : '❌ Not available',
        'JSON Support' => function_exists('json_encode') ? '✅ Available' : '❌ Not available',
        'cURL Support' => function_exists('curl_init') ? '✅ Available' : '❌ Not available',
        'OpenSSL' => extension_loaded('openssl') ? '✅ Loaded' : '❌ Not loaded',
        'PDO' => extension_loaded('pdo') ? '✅ Loaded' : '❌ Not loaded'
    ];
    
    $test_html = '';
    foreach($tests as $test => $result) {
        $test_html .= '<li><strong>' . htmlspecialchars($test) . ':</strong> ' . $result . '</li>';
    }
    
    return '
    <div class="container">
        <h1>🧪 Feature Tests</h1>
        <p><a href="?page=home" class="btn">← Back to Home</a></p>
        
        <div class="info">
            <h3>PHP Extensions & Features</h3>
            <ul>' . $test_html . '</ul>
        </div>
        
        <div class="info">
            <h3>Environment Test</h3>
            <p><strong>Current Time:</strong> ' . date('Y-m-d H:i:s') . '</p>
            <p><strong>Memory Usage:</strong> ' . round(memory_get_usage() / 1024 / 1024, 2) . ' MB</p>
            <p><strong>Peak Memory:</strong> ' . round(memory_get_peak_usage() / 1024 / 1024, 2) . ' MB</p>
        </div>
    </div>';
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo htmlspecialchars($config['app_name']); ?></title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            max-width: 1000px;
            margin: 0 auto;
            padding: 2rem;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            padding: 2rem;
            border-radius: 10px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        h1 {
            text-align: center;
            margin-bottom: 2rem;
            font-size: 2.5rem;
        }
        .status {
            background: rgba(0, 255, 0, 0.2);
            padding: 1rem;
            border-radius: 5px;
            margin: 1rem 0;
            border-left: 4px solid #00ff00;
        }
        .info {
            background: rgba(255, 255, 255, 0.1);
            padding: 1rem;
            border-radius: 5px;
            margin: 1rem 0;
        }
        .btn {
            display: inline-block;
            background: rgba(255, 255, 255, 0.2);
            color: white;
            padding: 0.5rem 1rem;
            text-decoration: none;
            border-radius: 5px;
            margin: 0.25rem;
            border: 1px solid rgba(255, 255, 255, 0.3);
            transition: all 0.3s ease;
        }
        .btn:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-2px);
        }
        code {
            background: rgba(0, 0, 0, 0.3);
            padding: 0.2rem 0.5rem;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
        .phpinfo {
            background: white;
            color: black;
            padding: 1rem;
            border-radius: 5px;
            overflow-x: auto;
            max-height: 600px;
            overflow-y: auto;
        }
        .phpinfo table {
            width: 100%;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
    <?php echo renderPage($page, $config, $server_info); ?>
</body>
</html>