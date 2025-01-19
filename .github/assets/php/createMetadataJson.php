<?php

function fetch_metadata($p = '/'): ?array
{
    $t = file_get_contents("http://169.254.169.254/latest/api/token", false, stream_context_create(['http' => ['method' => 'PUT', 'header' => "X-aws-ec2-metadata-token-ttl-seconds: 21600\r\n"]]));
    $u = "http://169.254.169.254/latest/meta-data$p";
    $o = stream_context_create(['http' => ['method' => 'GET', 'header' => "X-aws-ec2-metadata-token: $t\r\n"]]);
    $r = file_get_contents($u, false, $o);
    if ($r === false) return null;
    $m = [];
    foreach (explode("\n", trim($r)) as $l) {
        $m[rtrim($l, '/')] = substr($l, -1) == '/' ? fetch_metadata("$p$l") : file_get_contents("$u/$l", false, $o);
    }
    return $m;
}

echo json_encode(fetch_metadata(), JSON_PRETTY_PRINT);
