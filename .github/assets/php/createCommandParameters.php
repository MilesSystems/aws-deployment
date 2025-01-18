<?php

if ($argc < 3) {
    echo "Usage: php script.php <commands_file> <platform>\n";
    exit(1);
}

$commandsFile = $argv[1];
$platform = strtolower($argv[2]);

try {
    $scriptContent = file_get_contents($commandsFile);

    // Encode the script content to hex
    $hexContent = bin2hex($scriptContent);

    $cachePath = DIRECTORY_SEPARATOR . 'tmp' . DIRECTORY_SEPARATOR . 'catFileRun';

    if (file_exists($cachePath)) {
        $catFile = ' cat /tmp/user_script.sh &&';
        if (!touch($cachePath)) {
            error_log("Failed to update cache file timestamp: $cachePath");
        }
    } else {
        $catFile = '';
    }

    if ($platform === 'linux') {
        $decodeAndExecute = "echo $hexContent | xxd -r -p > /tmp/user_script.sh && $catFile source /tmp/user_script.sh";
        $parameterJson = json_encode([
            'command' => [
                "sudo bash -c '$decodeAndExecute'"
            ]
        ], JSON_THROW_ON_ERROR);
        $outputFile = __DIR__ . DIRECTORY_SEPARATOR . 'commandParametersLinux.json';
    } elseif ($platform === 'windows') {
        $decodeAndExecute = "echo $hexContent | certutil -decodehex -f - 4 C:\\Windows\\Temp\\user_script.ps1 && type C:\\Windows\\Temp\\user_script.ps1 && powershell -ExecutionPolicy Bypass -File C:\\Windows\\Temp\\user_script.ps1";
        $parameterJson = json_encode([
            'command' => [
                "powershell -Command \"$decodeAndExecute\""
            ]
        ], JSON_THROW_ON_ERROR);
        $outputFile = __DIR__ . DIRECTORY_SEPARATOR . 'commandParametersWindows.json';
    } else {
        throw new InvalidArgumentException('Invalid platform specified. Use "linux" or "windows".');
    }

    if (false === file_put_contents($outputFile, $parameterJson . PHP_EOL)) {
        throw new RuntimeException('Failed to write JSON to file');
    }

    echo $outputFile;

} catch (Throwable $e) {
    echo 'Error: ' . $e->getMessage() . PHP_EOL;
    exit(1);
}
