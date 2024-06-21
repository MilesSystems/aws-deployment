<?php

function tabEverything($content, $tab = 6): string
{
    # tabs in yaml are 2 spaces
    return implode("\n", array_map(static fn($line) => str_repeat("  ", $tab) . $line, explode("\n", $content)));
}

$scriptBoot = tabEverything(file_get_contents($argv[1]));

// input the web.yaml file as string then
$deployYamlPath = './CloudFormation/web.yaml';

$imageBuilderYamlFile = file_get_contents($deployYamlPath);

$find = <<<EOF
        UserData:
          Fn::Base64: |
EOF;

$processedYamlFile = str_replace($find, $find . PHP_EOL . $scriptBoot, $imageBuilderYamlFile);

echo $processedYamlFile;

if (false === file_put_contents($deployYamlPath, $processedYamlFile)) {
    echo "Error: Unable to write to $deployYamlPath\n";
    exit(2);
}

