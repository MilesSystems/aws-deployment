<?php


try {

    echo json_encode([
        "description" => "Copies AMI to other regions and allows deployment on shared network",
        "distributions" => array_map(static function ($region) use ($argv) {
            return [
                "region" => $region,
                "amiDistributionConfiguration" => [
                    "name" => "version {{imagebuilder:buildVersion}} date {{imagebuilder:buildDate}} account $argv[1]",
                    "launchPermission" => [
                        "userIds" => [
                            $argv[1],   // AWS account ID - to deploy to
                            $argv[2]    // AWS account ID - the shared networking account (vpc hosting account)
                        ]
                    ]
                ]
            ];
        }, json_decode($argv[3], true, 512, JSON_THROW_ON_ERROR)['aws-region'])
    ], JSON_THROW_ON_ERROR);

} catch (JsonException $e) {

    print 'Error: ' . $e->getMessage() . PHP_EOL;

    exit(2);

}
