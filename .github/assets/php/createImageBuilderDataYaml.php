<?php

function tabEverything($content, $tab = 7)
{
    # tabs in yaml are 2 spaces
    return implode("\n", array_map(static fn($line) => str_repeat("  ", $tab) . $line, explode("\n", $content)));
}

$scriptBuild = tabEverything(file_get_contents($argv[1]));
$scriptValidate = tabEverything(file_get_contents($argv[2]));

$timeout = getenv('IMAGE_BUILDER_STEP_TIMEOUT_SECONDS') ?: '1200';

$yamlContent = <<<EOD
name: Install Server Software
description: Installs server software for EC2 instances
schemaVersion: 1.0
phases:
  - name: build
    steps:
      - name: CustomBuildEc2Image
        action: ExecuteBash
        timeoutSeconds: $timeout
        onFailure: Abort
        maxAttempts: 1
        inputs:
          commands:
            - |
$scriptBuild
  - name: validate
    steps:
      - name: CustomValidate
        action: ExecuteBash
        inputs:
          commands:
            - |
$scriptValidate
EOD;

// input the imagebuilder.yaml file as string then

$imageBuilderYamlPath = './CloudFormation/imagebuilder.yaml';

$imageBuilderYamlFile = file_get_contents($imageBuilderYamlPath);

$yamlContent = tabEverything($yamlContent, 4);

$processedYamlFile = str_replace('Data: |', 'Data: |' . PHP_EOL . $yamlContent, $imageBuilderYamlFile);

echo $processedYamlFile;

if (false === file_put_contents($imageBuilderYamlPath, $processedYamlFile)) {
    echo "Error: Unable to write to $imageBuilderYamlPath\n";
    exit(2);
}

