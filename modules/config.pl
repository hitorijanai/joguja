#!/usr/bin/perl

package DaijoBB;

$site_name = "http://localhost/index.pl"; #change the path to the actual site location

$start_mode = "index";

$path_to_source = "/home/affath/www/modules/"; #change the path to the actual full path of module location
$path_to_template = "/home/affath/www/templates/"; #change the path to the actual full path of template location

$db_location = "DBI:mysql:database=DBTest;host=localhost;port=3306";
$db_account = "root";
$db_password = "root";

$admin_password = "wakarimasen";

$page_limit = 10;
