<?php
	$data_file = fopen("text.txt", "w");
	$storage = $_POST["storage"];
	$loadType = $_POST["loadType"];
	$location = $_POST["location"];
	$text_to_write = $storage . " " . $loadType;
	fwrite($data_file, $text_to_write);
	fclose($data_file);
?>
