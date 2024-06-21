<?php

/**
 * Parse command-line arguments into an associative array.
 *
 * @param array $argv Command-line arguments.
 * @return array Parsed arguments.
 */
function parseArguments(array $argv): array
{
    $args = [];
    foreach ($argv as $arg) {
        if (strpos($arg, '--') === 0) {
            $key = substr($arg, 2);
            $value = true; // Default value if no explicit value is given
            if (strpos($key, '=') !== false) {
                [$key, $value] = explode('=', $key, 2);
            }
            $args[$key] = $value;
        }
    }
    return $args;
}

/**
 * Read the content of a script file.
 *
 * @param string $filePath Path to the script file.
 * @return string Script content.
 * @throws InvalidArgumentException if the file does not exist.
 */
function getScriptContent(string $filePath): string
{
    if (!file_exists($filePath)) {
        throw new InvalidArgumentException("File not found: $filePath");
    }
    return file_get_contents($filePath);
}

try {

    // Parse command-line arguments
    $arguments = parseArguments($argv);

    // Validate arguments and prepare parameter array
    $parameters = [];

    foreach ($arguments as $key => $value) {

        // For ScriptBuild and ScriptValidate, read file content
        if (str_contains($key, 'Data' )) {

            $value = getScriptContent($value);

        }

        $parameters[] = [
            'ParameterKey' => $key,
            'ParameterValue' => $value
        ];

    }

    // Encode parameters as JSON
    $parametersJson = json_encode($parameters, JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT);

    // Write JSON to file
    $storeToFile = './imageBuilderParameters.json';

    if (file_put_contents($storeToFile, $parametersJson . PHP_EOL) === false) {
        throw new RuntimeException('Failed to write JSON to file');
    }

    // Output the file path
    echo $storeToFile;

} catch (InvalidArgumentException $e) {
    echo 'Error: ' . $e->getMessage() . PHP_EOL;
    exit(1);
} catch (JsonException $e) {
    echo 'JSON Error: ' . $e->getMessage() . PHP_EOL;
    exit(1);
} catch (RuntimeException $e) {
    echo 'Runtime Error: ' . $e->getMessage() . PHP_EOL;
    exit(1);
}

