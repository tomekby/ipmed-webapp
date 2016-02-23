$old_name = "Eugeniusz_Kowalski";
for($i = 0; $i < $ARGV[0]; ++$i) {
	rename "c:/ipmed/input/${old_name}.xlsx", "c:/ipmed/input/${old_name}1.xlsx";
	$old_name = "${old_name}1";
	system('curl -u q:qwe localhost:8081/patients/kowalski > NUL');
}