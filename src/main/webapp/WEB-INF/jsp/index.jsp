<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>IPMed</title>

    <!-- Bootstrap -->
    <link rel="stylesheet" href="media/css/bootstrap-select.css">
    <link rel="stylesheet" href="media/css/bootstrap.min.css">
    <link rel="stylesheet" href="media/css/animation.css">
    <link rel="stylesheet" href="media/css/skins/minimal/minimal.css">
    <link rel="stylesheet" href="media/css/bootstrap-datetimepicker.min.css">
    <link rel="stylesheet" href="media/css/style.css">
	<link rel="stylesheet" href="media/css/font-awesome.min.css">
	<link rel="stylesheet" href="media/css/dataTables.bootstrap.css">
    <!-- HTML5 Shim and Respond.js IE8 support of HTML5 elements and media queries -->
    <!-- WARNING: Respond.js doesn't work if you view the page via file:// -->
    <!--[if lt IE 9]>
    <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
    <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->
    <link rel="stylesheet" href="media/css/bootstrapValidator.min.css">
</head>
<body>
<nav class="navbar navbar-inverse navbar-fixed-top" role="navigation">
    <div class="container-fluid">
        <div class="navbar-header">
            <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#bs-navbar-collapse">
                <span class="sr-only">Przełącz nawigację</span>
                <span class="icon-bar"></span>
                <span class="icon-bar"></span>
                <span class="icon-bar"></span>
            </button>
            <a class="navbar-brand hidden-xs hidden-sm" href="#">
				<img alt="IPMed" src="media/logo.png"> IPMed
			</a>
        </div>

        <div class="collapse navbar-collapse" id="bs-navbar-collapse">
            <ul class="nav navbar-nav">
                <li class="login"><a href="#new-measurements">Nowe pomiary <span class="badge" id="measurements-badge"></span></a></li>
                <li class="login"><a href="#to-fill">Do uzupełnienia <span class="badge" id="to-fill-badge"></span></a></li>
                <li class="login"><a href="#phones">Telefony <span class="badge" id="phones-badge"></span></a></li>
                <li class="login"><a href="#all-measurements">Wszystkie pomiary</a></li>
                <li class="login"><a href="#all-examinations">Wszyscy pacjenci</a></li>
                <li class="login hidden-lg"><a href="#logout">Wyloguj</a></li>
            </ul>
            <ul class="nav navbar-nav navbar-right visible-lg">
                <li class="login"><p class="navbar-text">Sesja wygaśnie za: <span id="logout-timer">0:00</span></p></li>
                <li class="login"><p class="navbar-text">|</p></li>
                <li class="login"><p class="navbar-text">Zalogowano jako <span style="font-weight:bold" id="username"></span></p></li>
                <li class="login"><span><a class="btn btn-primary btn-sm navbar-btn" href="#logout">Wyloguj</a></span></li>
            </ul>
        </div><!-- /.navbar-collapse -->
    </div><!-- /.container-fluid -->
</nav>
<!-- overlay informujący o ładowaniu się strony -->
<div id="ajaxOverlay"></div>
<!-- właściwa treść strony -->
<div class="container-fluid">
    <div class="row"><!-- formularz logowania -->
        <div class="col-md-4 col-md-offset-4">
			<h3 class="text-center">Logowanie do systemu IPMED</h3>
            <form id="login-page" class="form-horizontal" action="" method="POST" data-bv-live="enabled">
                <div class="form-group">
                    <label for="login" class="col-sm-3 control-label">Użytkownik:</label>
                    <div class="col-sm-9">
                        <input type="text" class="form-control" placeholder="Nazwa użytkownika" id="login" name="login" autofocus>
                    </div>
                </div>
                <div class="form-group">
                    <label for="passwd" class="col-sm-3 control-label">Hasło:</label>
                    <div class="col-sm-9">
                        <input type="password" class="form-control" placeholder="Hasło" id="passwd" name="passwd">
                    </div>
                </div>
                <div class="form-group">
                    <div class="col-sm-12">
                        <button type="submit" class="btn btn-primary col-sm-12">ZALOGUJ</button>
                    </div>
                </div>
            </form>
        </div>
    </div>
    <div class="row" id="after-login" style="display: none;"><!-- to co po zalogowaniu (później podmiana via AJAX) -->
        <div class="col-sm-12" id="page-logged-in-content"></div>
        <!-- divy z zawartością poszczególnych podstron -->
        <div id="subpages-content" class="col-sm-12">
            <div id="new-measurements-div" style="display:none;"></div>
            <div id="to-fill-div" style="display:none;"></div>
            <div id="phones-div" style="display:none;"></div>
            <div id="all-measurements-div" style="display:none;"></div>
            <div id="all-examinations-div" style="display:none;"></div>
            <div id="tmp" style="display:none;"></div>
        </div>

    </div>
</div>

<div class="footer">
    <div class="container">
        <p class="text-muted small">&copy; <a href="http://tomekby.vot.pl/">Tomasz Stasiak</a> 2014r.</p>
    </div>
</div>

<script type="text/javascript" src="media/js/vendor/lazy.min.js"></script>
<script type="text/javascript" src="media/js/vendor/jquery.min.js"></script>
<script type="text/javascript" src="media/js/vendor/bootstrapValidator.min.js"></script>
<script type="text/javascript" src="media/js/vendor/moment.min.js"></script>
<script type="text/javascript" src="media/js/vendor/moment-timezone.min.js"></script>
<script type="text/javascript" src="media/js/vendor/dataTables.js"></script>
<script type="text/javascript" src="media/js/vendor/bootstrapDataTable.js"></script>
<script type="text/javascript" src="media/js/vendor/bootstrap.min.js"></script>
<script type="text/javascript" src="media/js/vendor/bootbox.min.js"></script>
<script type="text/javascript" src="media/js/vendor/json.js"></script>
<script type="text/javascript" src="media/js/vendor/pl_PL.js"></script>
<script data-main="media/js/scripts" src="media/js/vendor/require.js"></script>
<!-- KGMpIFRvbWFzeiBTdGFzaWFr -->
</body>
</html>