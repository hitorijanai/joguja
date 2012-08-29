#!/usr/bin/perl -w


use CGI::Carp qw(fatalsToBrowser);
# ================================================================================
package CGI::as_utf8;  # add UTF-8 decode capability to CGI.pm
BEGIN {
  use strict;
  use warnings;
  use CGI 3.47;  # earlier versions have a UTF-8 double-decoding bug
  {   no warnings 'redefine';
      my $param_org = \&CGI::param;
      my $might_decode = sub {
          my $p = shift;
          # make sure upload() filehandles are not modified
          return $p if !$p || ( ref $p && fileno($p) );
          utf8::decode($p);  # may fail, but only logs an error
          $p
      };
      *CGI::param = sub {
          # setting a param goes through the original interface
          goto &$param_org if scalar @_ != 2;
          my $q = $_[0];    # assume object calls always
          my $p = $_[1];
          return wantarray
              ? map { $might_decode->($_) } $q->$param_org($p)
              : $might_decode->( $q->$param_org($p) );
      }
  }
}

package DaijoBB;

use 5.010;
use utf8;
use base 'CGI::Application';
use strict;
use autodie;
use HTML::Template;
use HTML::Entities;
use CGI::Application::Plugin::DBH qw/dbh_config dbh/;
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::Redirect;
use Parse::BBCode;


require 'config.pl';



sub setup {
    my $self = shift;
	$self->header_add(-charset => 'utf-8');
    $self->run_modes(
        'index' => 'index_m',
        'do_login' => 'do_login_m',
        'logout' => 'logout_m',
        'register' => 'register_m',
        'do_register' => 'do_register_m',
        'showtopic' => 'showtopic_m',
        'posttopic' => 'posttopic_m',
        'posttopic_confirm' => 'posttopic_confirm_m',
        'do_posttopic' => 'do_posttopic_m',
        'postreply' => 'postreply_m',
        'postreply_confirm' => 'postreply_confirm_m',
        'do_postreply' => 'do_postreply_m',
        'do_postaction' => 'do_postaction_m',
        'adminpage' => 'adminpage_m',
        'do_loginadmin' => 'do_loginadmin_m',
        'search' => 'search_m'
    );
    $self->start_mode($DaijoBB::start_mode);
    $self->tmpl_path($DaijoBB::path_to_template);
}

sub cgiapp_init{
    my $self    = shift;
    my $query   = $self->query;

	$self->query->charset('UTF-8');
    $self->session_config(
        CGI_SESSION_OPTIONS => [ "driver:File", $self->query, {Directory=>'/tmp/'} ],
        COOKIE_PARAMS       =>  {
                                   -expires => '+1w',
                                   -path    => '/',
                                },
        SEND_COOKIE         => 1
    );
    $self->dbh_config(
        $DaijoBB::db_location,
        $DaijoBB::db_account,
        $DaijoBB::db_password,
        {mysql_enable_utf8 => 1});
	$self->dbh->do("SET NAMES 'utf8'");
	$self->dbh->do("SET collation_connection = utf8_general_ci");
    $self->dbh->do("SET CHARACTER SET utf8");
	$self->header_add(-charset => 'utf-8');
}

sub escape_unsafe_chars(){
    my $self = shift;
    return encode_entities((my $param = shift),'<>"\'()')
}

sub index_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    
    my $tmpl = $self->load_tmpl("index.tmpl", utf8=> 1);
    $tmpl->param(TITLE => "Welcome to DaijoBB Forum");
    $tmpl->param(LOGGED_IN => $session->param('user_idx'));
    $tmpl->param(USERNAME => $session->param('username'));
    $tmpl->param(LOGIN_FAILED => $session->param('login_failed'));
    $session->param('login_failed', undef);
    
    my $page = $q->param('page') - 1 if ($q->param('page'));
    
    my $sth = $self->dbh->prepare(
    "SELECT t.thread_idx, ts.username, t.title, t.view_count, t.reply_count, r.username, t.last_reply_date
    FROM thread AS t, user AS ts, user AS r
    WHERE ts.user_idx = t.user_idx AND r.user_idx = t.last_reply_user_idx
    ORDER BY t.last_reply_date DESC
    LIMIT ?, ?");
    
    $sth->execute($page*$DaijoBB::page_limit, $DaijoBB::page_limit);
    
    my $total_page = int(($self->dbh->do("SELECT thread_idx FROM thread")-1) / $DaijoBB::page_limit);
    
    my @rows;
    while(my @row = $sth->fetchrow_array()){
        my %row_data;
        $row_data{THREAD_IDX} = shift @row;
        $row_data{THREAD_STARTER} = shift @row;
        $row_data{TOPIC} = shift @row;
        $row_data{VIEW_COUNT} = shift @row;
        $row_data{REPLY_COUNT} = shift @row;
        $row_data{LAST_POSTER} = shift @row;
        $row_data{LAST_POST_DATE} = POSIX::strftime("%Y年%m月%d日 %H:%M", localtime(my $time = shift @row));
        $row_data{IS_NEW} = ((time - $time)/3600 < 24)?1:undef;
        push @rows, \%row_data;
    }
    
    my $prev = ($page-2 >= 0)?$page-1:1;
    my $next = ($page+2 < $total_page)?$page+3:$total_page+1;
    
    my @pages = ($prev..$next);
    my @nav_pages;
    unshift @nav_pages, 1 if ($prev > 1);
    push @nav_pages, $total_page+1 if ($next <= $total_page);
    foreach (@pages){
        push @nav_pages, {PAGE_NUM => $_};
    }
    
    $tmpl->param(THREAD_LIST => \@rows);
    $tmpl->param(PAGE_RM => 'index');
    $tmpl->param(PREV_PAGE => (($page)?$page:undef));
    $tmpl->param(NEXT_PAGE => (($page < $total_page)?$page+2:undef));
    $tmpl->param(NAV_PAGES => \@nav_pages);
    
    return $tmpl->output;
}

sub do_login_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    
    my $sth = $self->dbh->prepare('SELECT user_idx FROM user WHERE username = ? AND password = MD5(?)');
    $sth->execute($q->param('USERNAME'), $q->param('PASSWORD'));
    
    $session->clear;
    
    if (my $user_idx = ($sth->fetchrow_array())[0]) {
        $session->param('user_idx', $user_idx);
        $session->param('username', $q->param('USERNAME'));
        return $self->redirect($DaijoBB::site_name."?rm=index");
    } else {
    
        $session->param('login_failed', 1);
        return $self->redirect($DaijoBB::site_name."?rm=index");
    }
}

sub logout_m{
    my $self = shift;
    $self->session_delete;
    return $self->redirect($DaijoBB::site_name."?rm=index");
}

sub register_m{
    my $self = shift;
    my $session = $self->session;
    my $tmpl = $self->load_tmpl("register.tmpl", utf8=> 1);
    $tmpl->param(TITLE => "Registration");
    $tmpl->param(REGISTERING => 1);
    if (defined $session->param('register_failed')){
        $tmpl->param(REGISTER_ERROR => $session->param('register_failed'));
        $session->param('register_failed', undef);
    }
    return $tmpl->output;
}

sub do_register_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    
    my $result = $self->dbh->selectrow_array("SELECT user_idx FROM user WHERE username = ?", { }, $q->param('USERNAME'));
    if ($result) {
        $session->param("register_failed", "Username '".$q->param('USERNAME')."' already exists.");
        return $self->redirect($DaijoBB::site_name."?rm=register");
    }
    my $sth = $self->dbh->prepare("INSERT INTO user (username, password, email, fullname, join_date) VALUES (?, MD5(?), ?, ?, ?)");
    $result = $sth->execute($q->param("USERNAME"), $q->param("PASSWORD"), $q->param("EMAIL"), $q->param("FULLNAME"), time);
    
    if ($result){
        $session->clear;
        $session->param('user_idx', $self->dbh->last_insert_id(undef, undef, 'user', 'user_idx'));
        $session->param('username', $q->param('USERNAME'));
        return $self->redirect($DaijoBB::site_name."?rm=index");
    } else {
        $session->param("register_failed", "Error: could not register your account at this moment.");
        return $self->redirect($DaijoBB::site_name."?rm=register");
    }
}

sub showtopic_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    my $parser = Parse::BBCode->new();
    my ($thread_idx, $page) = ($q->param('id')+0, ($q->param('page')?$q->param('page')-1:0));
    my $total_page = int(($self->dbh->do("SELECT post_idx FROM post WHERE thread_idx = ?",{},($thread_idx))-1) / $DaijoBB::page_limit);
    my $topic_title = $self->dbh->selectrow_array('SELECT title FROM thread WHERE thread_idx = ?',{},$thread_idx);
    
    my $tmpl = $self->load_tmpl("showtopic.tmpl", utf8=> 1);
    $tmpl->{options}->{global_vars} = 1;
    $tmpl->param(TITLE => 'DaijoBB - '.$topic_title);
    $tmpl->param(LOGGED_IN => $session->param('user_idx'));
    $tmpl->param(USERNAME => $session->param('username'));
    
    my $sth = $self->dbh->prepare('SELECT p.post_idx, p.title, p.message, p.date_created, u.user_idx, u.username, u.total_post, u.join_date FROM post as p, user as u WHERE p.thread_idx = ? AND u.user_idx = p.user_idx ORDER BY p.date_created LIMIT ?, ?');
    $sth->execute($thread_idx, $page*$DaijoBB::page_limit, $DaijoBB::page_limit);
    
    $self->dbh->do('UPDATE thread SET view_count = view_count + 1 WHERE thread_idx = ?',{}, ($thread_idx));
    
    my @rows;
    
    while (my @row = $sth->fetchrow_array()){
        my %a_post;
        $a_post{POST_ID} = shift @row;
        $a_post{POST_TITLE} = shift @row;
        $a_post{POST_BODY_HTML} = $parser->render(shift @row);
        $a_post{POST_DATE} = POSIX::strftime("%Y年%m月%d日 %H:%M", localtime(my $time = shift @row));
        my $user_idx = shift @row;
        $a_post{PROF_NAME} = shift @row;
        my ($total_post, $join_date) = (shift(@row), shift(@row));
        if ($user_idx){
            $a_post{PROF_TOTAL_POST} = $total_post;
            $a_post{PROF_JOIN_DATE} = POSIX::strftime("%Y年%m月%d日 %H:%M", localtime($join_date));
        }
        $a_post{TID} = $thread_idx;
        $a_post{PID} = $a_post{POST_ID},
        $a_post{NPAGE} = ($page+1);
        $a_post{ALLOW_DELETE} = ($user_idx > 0 && $user_idx == $session->param('user_idx')) || (defined $session->param('admin'));
        push @rows, \%a_post;
    }
    
    
    my $prev = ($page-2 >= 0)?$page-1:1;
    my $next = ($page+2 < $total_page)?$page+3:$total_page+1;
    
    my @pages = ($prev..$next);
    my @nav_pages;
    unshift @nav_pages, 1 if ($prev > 1);
    push @nav_pages, $total_page+1 if ($next <= $total_page);
    foreach (@pages){
        push @nav_pages, {PAGE_NUM => $_};
    }
    
    my @index;
    push @index, {INDEX_NAME => "「".$topic_title."」", INDEX_LINK => "index.pl?rm=showtopic&id=$thread_idx"};
    
    $tmpl->param(PAGE_RM => "showtopic&id=$thread_idx");
    $tmpl->param(CURRENT_INDEX => \@index);
    $tmpl->param(POSTS => \@rows);
    $tmpl->param(NAV_PAGES => \@nav_pages);
    
    return $tmpl->output;
}


sub posttopic_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    
    my $tmpl = $self->load_tmpl("posttopic.tmpl", utf8=> 1);
    $tmpl->param(TITLE => "Create Topic");
    $tmpl->param(LOGGED_IN => $session->param('user_idx'));
    $tmpl->param(USERNAME => $session->param('username'));
    
    my @hidden_post;
    push @hidden_post, {HP_NAME => "rm", HP_VALUE => "posttopic_confirm"};
    my @index;
    push @index, {INDEX_NAME => "Create Topic", INDEX_LINK => undef};
    $tmpl->param(CURRENT_INDEX => \@index);
    $tmpl->param(HIDDEN_POST => \@hidden_post);
    
    return $tmpl->output;
}

sub posttopic_confirm_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    my $parser = Parse::BBCode->new();
    my ($post_title, $post_body) = ($self->escape_unsafe_chars($q->param('POST_TITLE')), $q->param('POST_BODY'));
    
    my $tmpl = $self->load_tmpl("postconfirm.tmpl", utf8=> 1);
    
    my %a_post;
    
    $tmpl->param(TITLE => ("Create Topic"));
    $tmpl->param(LOGGED_IN => $session->param('user_idx'));
    $tmpl->param(USERNAME => $session->param('username'));
    
    my ($join_date, $total_post);
    if ($session->param('user_idx') > 0){
      ($join_date, $total_post) = $self->dbh->selectrow_array('SELECT join_date, total_post FROM user WHERE user_idx = ?', {}, $session->param('user_idx'));
    }
    
    $a_post{PROF_NAME} = ($session->param('username') || 'Guest');
    $a_post{PROF_JOIN_DATE} = POSIX::strftime("%Y年%m月%d日 %H:%M", localtime($join_date));
    $a_post{PROF_TOTAL_POST} = $total_post;
    $a_post{POST_TITLE} = $post_title;
    $a_post{POST_BODY_HTML} = $parser->render($post_body);
    $a_post{CONFIRMATION} = 1;
    
    my @posts = (\%a_post);
    
    my @index;
    push @index, {INDEX_NAME => "Create Topic", INDEX_LINK => "index.pl?rm=posttopic"};
    push @index, {INDEX_NAME => "Confirmation"};
    
    my @hidden_post;
    push @hidden_post, {HP_NAME => "rm", HP_VALUE => "do_posttopic"};
    push @hidden_post, {HP_NAME => "POST_TITLE", HP_VALUE => $post_title};
    push @hidden_post, {HP_NAME => "POST_BODY", HP_VALUE => $self->escape_unsafe_chars($post_body)};
    
    $tmpl->param(POSTS => \@posts);
    $tmpl->param(CURRENT_INDEX => \@index);
    $tmpl->param(HIDDEN_POST => \@hidden_post);
        
    return $tmpl->output;
}

sub do_posttopic_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    
    my $user_idx = $session->param('user_idx') || 0;
    my $date_created = time;
    my ($post_title, $post_body) = ($self->escape_unsafe_chars($q->param('POST_TITLE')), decode_entities($q->param('POST_BODY')));
    
    $self->dbh->do(
        'INSERT INTO thread (user_idx, title, last_reply_user_idx, last_reply_date) VALUES (?, ?, ?, ?)',
        {}, ($user_idx, $post_title, $user_idx, $date_created)) or die "ERROR ".$self->dbh->err;
        
    my $thread_idx = $self->dbh->last_insert_id(undef, undef, 'thread', 'thread_idx');
    
    $self->dbh->do('INSERT INTO post (thread_idx, user_idx, title, message, date_created) VALUES (?, ?, ?, ?, ?)',
        {}, ($thread_idx, $user_idx, $post_title, $post_body, $date_created)) or die "ERROR ".$self->dbh->err;
    $self->dbh->do('UPDATE user SET total_post = total_post + 1 WHERE user_idx = ?',{},($user_idx)) if ($user_idx > 0);
    return $self->redirect('index.pl');
}

sub do_postaction_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    
    my ($thread_idx, $post_idx, $page, $mode, $user_idx) = ($q->param('tid'), $q->param('pid'), $q->param('page'), $q->param('mode'), $session->param('user_idx'));    
        
    if ($mode eq 'reply'){
        return $self->redirect("index.pl?rm=postreply&tid=$thread_idx");
    } elsif ($mode eq 'delete') {
        if (defined $session->param('admin')){
            $self->dbh->do('DELETE FROM post WHERE post_idx = ?',{},($post_idx));
            
            if ($self->dbh->do('SELECT post_idx FROM post WHERE thread_idx = ?',{},$thread_idx) == 0){
                $self->dbh->do('DELETE FROM thread WHERE thread_idx = ?',{},($thread_idx));
                return $self->redirect("index.pl");
            } else {
                $self->dbh->do('UPDATE thread SET reply_count = reply_count - 1 WHERE thread_idx = ?',{},($thread_idx));
            }
        } else {
            $self->dbh->do('DELETE FROM post WHERE post_idx = ? AND user_idx = ?',{},($post_idx,$user_idx));
            if ($self->dbh->do('SELECT post_idx FROM post WHERE thread_idx = ?',{},$thread_idx) == 0){
                $self->dbh->do('DELETE FROM thread WHERE thread_idx = ? AND user_idx = ?',{},($thread_idx,$user_idx));
                return $self->redirect("index.pl");
            } else {
                $self->dbh->do('UPDATE thread SET reply_count = reply_count - 1 WHERE thread_idx = ?',{},($thread_idx));
            }
        }
        
        return $self->redirect("index.pl?rm=showtopic&id=${thread_idx}&page=${page}");
    }
}

sub postreply_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    
    my $thread_idx = $q->param('tid');
    
    my $tmpl = $self->load_tmpl("posttopic.tmpl", utf8=> 1);
    $tmpl->param(TITLE => "Post Reply");
    $tmpl->param(LOGGED_IN => $session->param('user_idx'));
    $tmpl->param(USERNAME => $session->param('username'));

    my $topic_title = $self->dbh->selectrow_array('SELECT title FROM thread WHERE thread_idx = ?',{},($thread_idx));


    my @index;
    push @index, {INDEX_NAME => "「".$topic_title."」", INDEX_LINK => "index.pl?rm=showtopic&id=$thread_idx"};
    push @index, {INDEX_NAME => "Post Reply"};
    
    my @hidden_post;
    push @hidden_post, {HP_NAME => "rm", HP_VALUE => "postreply_confirm"};
    push @hidden_post, {HP_NAME => "tid", HP_VALUE => $thread_idx};
    
    $tmpl->param(CURRENT_INDEX => \@index);
    $tmpl->param(HIDDEN_POST => \@hidden_post);
    
    return $tmpl->output;    
}

sub postreply_confirm_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    my $parser = Parse::BBCode->new();
    my ($post_title, $post_body) = ($self->escape_unsafe_chars($q->param('POST_TITLE')), $q->param('POST_BODY'));
    
    my $tmpl = $self->load_tmpl("postconfirm.tmpl", utf8=> 1);
    
    my %a_post;
    
    $tmpl->param(TITLE => ("Post Reply"));
    $tmpl->param(LOGGED_IN => $session->param('user_idx'));
    $tmpl->param(USERNAME => $session->param('username'));
    
    my ($join_date, $total_post);
    if ($session->param('user_idx') > 0){
      ($join_date, $total_post) = $self->dbh->selectrow_array('SELECT join_date, total_post FROM user WHERE user_idx = ?', {}, $session->param('user_idx'));
    }
    
    my $thread_idx = $q->param('tid');
    my $topic_title = $self->dbh->selectrow_array('SELECT title FROM thread WHERE thread_idx = ?',{},($thread_idx));
    
    $a_post{PROF_NAME} = ($session->param('username') || 'Guest');
    $a_post{PROF_JOIN_DATE} = POSIX::strftime("%Y年%m月%d日 %H:%M", localtime($join_date));
    $a_post{PROF_TOTAL_POST} = $total_post;
    $a_post{POST_TITLE} = $post_title;
    $a_post{POST_BODY_HTML} = $parser->render($post_body);
    $a_post{CONFIRMATION} = 1;
    
    my @posts = (\%a_post);
    
    my @index;
    push @index, {INDEX_NAME => "「".$topic_title."」", INDEX_LINK => "index.pl?rm=showtopic&id=$thread_idx"};
    push @index, {INDEX_NAME => "Post Reply", INDEX_LINK => "index.pl?rm=postreply&tid=$thread_idx"};
    push @index, {INDEX_NAME => "Confirmation"};
    
    my @hidden_post;
    push @hidden_post, {HP_NAME => "rm", HP_VALUE => "do_postreply"};
    push @hidden_post, {HP_NAME => "tid", HP_VALUE => $thread_idx};
    push @hidden_post, {HP_NAME => "POST_TITLE", HP_VALUE => $post_title};
    push @hidden_post, {HP_NAME => "POST_BODY", HP_VALUE => $self->escape_unsafe_chars($post_body)};
    
    $tmpl->param(POSTS => \@posts);
    $tmpl->param(CURRENT_INDEX => \@index);
    $tmpl->param(HIDDEN_POST => \@hidden_post);
        
    return $tmpl->output;
}

sub do_postreply_m{

    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    
    my $user_idx = $session->param('user_idx') || 0;
    my $date_created = time;
    my ($thread_idx, $post_title, $post_body) = (
        $q->param('tid'), 
        $self->escape_unsafe_chars($q->param('POST_TITLE')), 
        decode_entities($q->param('POST_BODY')));

    my $page = int(($self->dbh->do("SELECT post_idx FROM post WHERE thread_idx = ?",{},($thread_idx))-1) / $DaijoBB::page_limit)+1;    
    $self->dbh->do('INSERT INTO post (thread_idx, user_idx, title, message, date_created) VALUES (?, ?, ?, ?, ?)',
        {}, ($thread_idx, $user_idx, $post_title, $post_body, $date_created)) or die "ERROR ".$self->dbh->err."($thread_idx, $user_idx, $post_title, $post_body, $date_created)";
    $self->dbh->do('UPDATE user SET total_post = total_post + 1 WHERE user_idx = ?',{},($user_idx)) if ($user_idx > 0);
    $self->dbh->do('UPDATE thread SET reply_count = reply_count + 1, last_reply_user_idx = ?, last_reply_date = ? WHERE thread_idx = ?',{},($user_idx,$date_created,$thread_idx));
    return $self->redirect("index.pl?rm=showtopic&id=${thread_idx}&page=${page}");
}

sub adminpage_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    
    if ($session->param('user_idx') && $session->param('username')){
        return $self->redirect('index.pl?rm=index');
    }
    
    my $tmpl = $self->load_tmpl("admin.tmpl", utf8 => 1);
    

    my @index;
    push @index, {INDEX_NAME => "管理者ログイン"};    
    
    $tmpl->param(CURRENT_INDEX => \@index);
    return $tmpl->output;
}

sub do_loginadmin_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    
    if ($q->param('ADMIN_PASSWORD') eq $DaijoBB::admin_password){
        $session->param('user_idx', 9999);
        $session->param('username', 'admin');
        $session->param('admin', 1);
    }
    
    return $self->redirect('index.pl?rm=index');
}


sub search_m{
    my $self = shift;
    my $session = $self->session;
    my $q = $self->query;
    my $parser = Parse::BBCode->new();
    my ($keyword, $page) = ($q->param('keyword'), ($q->param('page')?$q->param('page')-1:0));
    my $safe_keyword = $self->escape_unsafe_chars($keyword);
    my $total_page = int(($self->dbh->do("SELECT post_idx FROM post WHERE (title LIKE ?) OR (message LIKE ?)",{},('%'.$safe_keyword.'%','%'.$keyword.'%')))/$DaijoBB::page_limit);
    
    
    my $tmpl = $self->load_tmpl("showtopic.tmpl", utf8=> 1);
    $tmpl->{options}->{global_vars} = 1;
    $tmpl->param(TITLE => '検索結果 - 「'.$safe_keyword.'」');
    $tmpl->param(LOGGED_IN => $session->param('user_idx'));
    $tmpl->param(USERNAME => $session->param('username'));
    
    my $sth = $self->dbh->prepare('SELECT p.thread_idx, p.post_idx, p.title, p.message, p.date_created, u.user_idx, u.username, u.total_post, u.join_date FROM post as p, user as u WHERE (p.title LIKE ? OR p.message LIKE ?) AND (u.user_idx = p.user_idx) ORDER BY p.date_created LIMIT ?, ?');
    $sth->execute('%'.$safe_keyword.'%','%'.$keyword.'%', $page*$DaijoBB::page_limit, $DaijoBB::page_limit);
    
    my @rows;
    
    while (my @row = $sth->fetchrow_array()){
        my %a_post;
        my $thread_idx = shift @row;
        $a_post{POST_ID} = shift @row;
        $a_post{POST_TITLE} = shift @row;
        $a_post{POST_BODY_HTML} = $parser->render(shift @row);
        $a_post{POST_DATE} = POSIX::strftime("%Y年%m月%d日 %H:%M", localtime(my $time = shift @row));
        my $user_idx = shift @row;
        $a_post{PROF_NAME} = shift @row;
        my ($total_post, $join_date) = (shift(@row), shift(@row));
        if ($user_idx){
            $a_post{PROF_TOTAL_POST} = $total_post;
            $a_post{PROF_JOIN_DATE} = POSIX::strftime("%Y年%m月%d日 %H:%M", localtime($join_date));
        }
        $a_post{TID} = $thread_idx;
        $a_post{PID} = $a_post{POST_ID},
        $a_post{NPAGE} = ($page+1);
        $a_post{CONFIRMATION} = 1;
        push @rows, \%a_post;
    }
    
    
    my $prev = ($page-2 >= 0)?$page-1:1;
    my $next = ($page+2 < $total_page)?$page+3:$total_page+1;
    
    my @pages = ($prev..$next);
    my @nav_pages;
    unshift @nav_pages, 1 if ($prev > 1);
    push @nav_pages, $total_page+1 if ($next <= $total_page);
    foreach (@pages){
        push @nav_pages, {PAGE_NUM => $_};
    }
    
    my @index;
    push @index, {INDEX_NAME => '検索結果 - 「'.$safe_keyword.'」'};
    
    $tmpl->param(PAGE_RM => "search&keyword=$keyword");
    $tmpl->param(CURRENT_INDEX => \@index);
    $tmpl->param(POSTS => \@rows);
    $tmpl->param(NAV_PAGES => \@nav_pages);
    
    return $tmpl->output;
}



1;


