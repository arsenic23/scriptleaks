<?php

if (isset($_GET['lua_name'])) {
    $luaName = $_GET['lua_name'];
    $directory = "scriptleaks/" . $luaName . "/";

    $output = array(
        "status" => "success",
        "luas" => array()
    );

    if (is_dir($directory)) {
        if ($dh = opendir($directory)) {
            while (($file = readdir($dh)) !== false) {
                if ($file != '.' && $file != '..') {
                    $filename = pathinfo($file, PATHINFO_FILENAME);
                    if (pathinfo($file, PATHINFO_EXTENSION) === 'lua') {
                       $output["luas"][] = $filename;
                    }
                }
            }
            closedir($dh);
        }
    } else {
        $output["status"] = "error";
        $output["message"] = "Directory not found.";
    }
} else {
    $output["status"] = "error";
    $output["message"] = "Lua name parameter missing.";
}

echo json_encode($output);

?>
