<?php

$output = array(
    "status" => "success",
    "luas" => array()
);

$baseDir = "scriptleaks/";

if (isset($_GET['luas_name'])) {
    // Search all subdirectories for the .lua file and return its base64-encoded contents
    $cfg_name = htmlspecialchars($_GET['luas_name']);
    $found = false;
    if (is_dir($baseDir)) {
        if ($dh = opendir($baseDir)) {
            while (($dir = readdir($dh)) !== false) {
                if ($dir != '.' && $dir != '..' && is_dir($baseDir . $dir)) {
                    $file_path = $baseDir . $dir . "/" . $cfg_name . ".lua";
                    if (file_exists($file_path)) {
                        $cfg_data = file_get_contents($file_path);
                        $output["luas"] = base64_encode($cfg_data);
                        $found = true;
                        break;
                    }
                }
            }
            closedir($dh);
        }
    }
    if (!$found) {
        $output["status"] = "error";
        $output["message"] = "file not found.";
    }
} else if (empty($_GET)) {
    // List all .lua files directly in the scriptleaks directory
    if (is_dir($baseDir)) {
        if ($dh = opendir($baseDir)) {
            while (($file = readdir($dh)) !== false) {
                if ($file != '.' && $file != '..' && pathinfo($file, PATHINFO_EXTENSION) === 'lua') {
                    $output["luas"][] = pathinfo($file, PATHINFO_FILENAME);
                }
            }
            closedir($dh);
        }
    } else {
        $output["status"] = "error";
        $output["message"] = "Base directory not found.";
    }
} else {
    $output["status"] = "error";
    $output["message"] = "Invalid parameters.";
}

echo json_encode($output);

?>
