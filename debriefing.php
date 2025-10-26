<?php

declare(strict_types=1);

require_once "./tacview.php";

?>
<!DOCTYPE html>
<html>
	<head>
		<title>PHPTacview</title>
		<link rel="stylesheet" href="tacview.css" />
		<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
	</head>
	<body>
		<div class="header-container">
			<a href="https://docs.google.com/spreadsheets/d/1gPK4ps2OQMKksESTPCNcuA6Ck8J7WJzPetBlyE4UP7I/edit?gid=923906759#gid=923906759&range=I1" class="logo-link" target="_blank">
				<img src="merc_logo.png" alt="Merc Logo" class="logo" />
			</a>
			<h1>PHP Tacview Debriefing</h1>
		</div>
		<?php

			$tv = new tacview("en");

			// Check for XML files
			$xmlFiles = glob("debriefings/*.xml");
			
			// Store status messages to display at the bottom
			$statusMessages = "<div style='margin-top: 40px; padding: 20px; border-top: 1px solid #333;'>";
			$statusMessages .= "<p>Looking for XML files in debriefings folder...</p>";
			$statusMessages .= "<p>Found " . count($xmlFiles) . " XML files.</p>";
			
			if (count($xmlFiles) == 0) {
				$statusMessages .= "<p>No XML files found. Looking for other files...</p>";
				$allFiles = glob("debriefings/*");
				$statusMessages .= "<ul>";
				foreach ($allFiles as $file) {
					$statusMessages .= "<li>" . basename($file) . "</li>";
				}
				$statusMessages .= "</ul>";
				$statusMessages .= "<p><strong>Note:</strong> This application currently processes XML files only. You have an .acmi file which needs to be converted to XML format.</p>";
			}

			foreach ($xmlFiles as $filexml) {
				$statusMessages .= "<h2>Processed: " . basename($filexml) . "</h2>";
				$tv->proceedStats("$filexml","Mission Test");
				echo $tv->getOutput();
			}
			
			$statusMessages .= "</div>";
			
			// Output status messages at the bottom
			echo $statusMessages;

		?>
	</body>
</html>