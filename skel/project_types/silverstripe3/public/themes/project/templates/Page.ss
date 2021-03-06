<!DOCTYPE html>

<!--[if !IE]><!-->
<html lang="$ContentLocale">
<!--<![endif]-->
<!--[if IE 6 ]><html lang="$ContentLocale" class="ie ie6"><![endif]-->
<!--[if IE 7 ]><html lang="$ContentLocale" class="ie ie7"><![endif]-->
<!--[if IE 8 ]><html lang="$ContentLocale" class="ie ie8"><![endif]-->

  <head>

    <% base_tag %>

    <title><% if $MetaTitle %>$MetaTitle<% else %>$Title<% end_if %> &raquo; $SiteConfig.Title</title>

    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    $MetaTags(false)

    <link rel="shortcut icon" href="themes/project/images/favicon.ico" type="image/x-icon" />
    <link rel="apple-touch-icon" href="themes/project/images/apple-touch-icon.png" />
    <link rel="apple-touch-icon" sizes="57x57" href="themes/project/images/apple-touch-icon-57x57.png" />
    <link rel="apple-touch-icon" sizes="60x60" href="themes/project/images/apple-touch-icon-60x60.png" />
    <link rel="apple-touch-icon" sizes="72x72" href="themes/project/images/apple-touch-icon-72x72.png" />
    <link rel="apple-touch-icon" sizes="76x76" href="themes/project/images/apple-touch-icon-76x76.png" />
    <link rel="apple-touch-icon" sizes="114x114" href="themes/project/images/apple-touch-icon-114x114.png" />
    <link rel="apple-touch-icon" sizes="120x120" href="themes/project/images/apple-touch-icon-120x120.png" />
    <link rel="apple-touch-icon" sizes="144x144" href="themes/project/images/apple-touch-icon-144x144.png" />
    <link rel="apple-touch-icon" sizes="152x152" href="themes/project/images/apple-touch-icon-152x152.png" />

  </head>
  <body>

    <div class="navbar">
      <div class="container">

        <!-- .navbar-toggle is used as the toggle for collapsed navbar content -->
        <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-responsive-collapse">
          <span class="icon-bar"></span>
          <span class="icon-bar"></span>
          <span class="icon-bar"></span>
        </button>

        <!-- Be sure to leave the brand out there if you want it shown -->
        <a class="navbar-brand" href="#">Title</a>

        <!-- Place everything within .nav-collapse to hide it until above 768px -->
        <div class="nav-collapse collapse navbar-responsive-collapse">
          <ul class="nav navbar-nav">
            <% loop Menu(1) %>
              <li class="<% if $LinkingMode == 'current' %>active<% end_if %>"><a href="$Link">$MenuTitle</a></li>
            <% end_loop %>    
          </ul>
        </div><!-- /.nav-collapse -->

      </div><!-- /.container -->
    </div><!-- /.navbar --> 

    <div class="container">
      $Layout
    </div>
    
  </body>

</html>