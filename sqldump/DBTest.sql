-- phpMyAdmin SQL Dump
-- version 3.4.10.1deb1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Aug 29, 2012 at 04:18 PM
-- Server version: 5.5.24
-- PHP Version: 5.3.10-1ubuntu3.2

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `DBTest`
--

-- --------------------------------------------------------

--
-- Table structure for table `post`
--

CREATE TABLE IF NOT EXISTS `post` (
  `post_idx` int(11) NOT NULL AUTO_INCREMENT,
  `thread_idx` int(11) NOT NULL,
  `user_idx` int(11) NOT NULL,
  `title` text NOT NULL,
  `message` text NOT NULL,
  `date_created` int(11) NOT NULL,
  PRIMARY KEY (`post_idx`),
  KEY `user_idx` (`user_idx`),
  KEY `thread_idx` (`thread_idx`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=45 ;

--
-- Dumping data for table `post`
--

INSERT INTO `post` (`post_idx`, `thread_idx`, `user_idx`, `title`, `message`, `date_created`) VALUES
(37, 34, 9999, 'サッカー ルール 蹴球規則', '[b]これはサッカー競技のフィールドに関して競技場の大きさからセンターラインやゴールライン、またゴールエリアやペナルティエリアなど場内の規則について説明するページです。競技場といえば国立競技場。試合を見に行ったら競技場から徒歩１５分と近くて便利なサッカーショップ加茂のメガエスタディオ原宿店をのぞいてみてください。巻　誠一郎、ロナウジーニョ、中田英寿、中村俊輔やルイスフィーゴ、ベッカムなどサッカー選手の情報も満載です。[/b]\r\n\r\n[color=#ff6600][b]競技場（フィールド）の大きさ[/b][/color]\r\n\r\n競技場の大きさは縦９０ｍ－１２０ｍ、横４５ｍ－９０ｍです。国際試合では最大で縦１１０ｍ×横７５ｍ、 最小で縦１００ｍ×横６４ｍと決められています。ちなみに、Ｗ杯やオリンピックでは、縦１０５ｍ×横６８ｍと なっていて、日本国内ではこの大きさを標準としています。\r\n\r\n[color=#ff6600][b]センターサークル[/b][/color]\r\n\r\nセンターマークを中心にセンターライン上に描かれた半径９．１５ｍの円のこと。この距離はフリーキックやコーナーキックなど、ボールが静止状態で始まるプレーに対して、相手競技者がボールから離れなければならない距離です。従って、キックオフやＰＫなども同様です。\r\n\r\n[color=#ff6600][b]ゴールエリア[/b][/color]\r\n\r\n両ゴールポストの内側から５．５ｍの所に直角に５．５ｍの線を引きその両端をゴールラインと水平に結んでできた四角い範囲。ゴールキックの時にボールを置くことができるエリアであり、キーパーが十分に保護されるエリアです。\r\n\r\n[color=#ff6600][b]ペナルティエリア[/b][/color]\r\n\r\n両ゴールポストの内側から１６．５ｍの所に直角に１６．５ｍの線を引きその両端をゴールラインと水平に結んでできた四角い範囲。ゴールキーパーは、このエリア内（自陣）でのみ手でボールを扱うことができます。また、ペナルティキックの際にはキッカーとキーパー以外はこのエリアの外に出なければなりません。ゴールキーパーはこのエリアの中ならボールを持ったまま自由に歩けます。ただしボールを持てる時間は６秒間だけです。', 1346115190),
(38, 34, 0, '', '[b]わかりました!![/b]　ありがとう先生', 1346115283),
(39, 34, 0, '', 'これからがんばります！　[color=#ff0000]^^ｙ[/color]', 1346115461),
(40, 34, 9999, '', 'はい！がんばりましょう!\r\n\r\n[img]http://livedoor.blogimg.jp/matsuokarikio/imgs/5/b/5b15176e.jpg[/img]', 1346115658),
(41, 35, 16, '毎日たこやき', 'たこやきはおいしいです。私のうちの近くにたこやきやがありいます。毎日あのやでたこやきをたくさん食べます、とてもおいしいですから。', 1346196366),
(42, 35, 16, '', 'あーー　あのたこやきの写真を忘れました！今を見せます、この下の写真を見てください。\r\n\r\n[img]http://www.walkerplus.net/gourmet/special/konamon/image/5DEMJ001_a.jpg[/img]', 1346196586),
(43, 35, 16, '&lt;Atarashii!&gt; &lt;div&gt;', '<div> </div>\r\n\r\n\r\n\r\n\r\n<form><input type="password" /></form>', 1346220404),
(44, 35, 0, '', '[b]Looks delicious[/b]! Where can I find one like that?', 1346222367);

-- --------------------------------------------------------

--
-- Table structure for table `thread`
--

CREATE TABLE IF NOT EXISTS `thread` (
  `thread_idx` int(11) NOT NULL AUTO_INCREMENT,
  `user_idx` int(11) NOT NULL,
  `title` text NOT NULL,
  `view_count` int(11) NOT NULL DEFAULT '0',
  `reply_count` int(11) NOT NULL DEFAULT '0',
  `last_reply_user_idx` int(11) NOT NULL,
  `last_reply_date` int(11) NOT NULL,
  PRIMARY KEY (`thread_idx`),
  KEY `user_idx` (`user_idx`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=36 ;

--
-- Dumping data for table `thread`
--

INSERT INTO `thread` (`thread_idx`, `user_idx`, `title`, `view_count`, `reply_count`, `last_reply_user_idx`, `last_reply_date`) VALUES
(34, 9999, 'サッカー ルール 蹴球規則', 15, 3, 9999, 1346115658),
(35, 16, '毎日たこやき', 10, 3, 0, 1346222367);

-- --------------------------------------------------------

--
-- Table structure for table `user`
--

CREATE TABLE IF NOT EXISTS `user` (
  `user_idx` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(16) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `password` varchar(32) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `email` varchar(32) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `fullname` varchar(20) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `join_date` int(11) NOT NULL,
  `total_post` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`user_idx`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=10000 ;

--
-- Dumping data for table `user`
--

INSERT INTO `user` (`user_idx`, `username`, `password`, `email`, `fullname`, `join_date`, `total_post`) VALUES
(0, 'Guest', '-', '-', 'Guest', 0, 0),
(4, 'pompompurin', '1e324d773f51cae7fc1d415974a4dfd6', 'dorodaor', '小さな祈り', 1346001723, 0),
(16, 'testo', '69e153e4d7add22f245e24de590eec21', 'testo', 'testo', 1346000726, 9),
(18, 'pikapika021', 'f8d1e57447a2556bcb47ad5706d02882', 'neon@gmail.com', 'Jagoan Semesta', 1346002726, 1),
(9999, 'admin', '', '', '', 1346001723, 4);

--
-- Constraints for dumped tables
--

--
-- Constraints for table `post`
--
ALTER TABLE `post`
  ADD CONSTRAINT `post_ibfk_1` FOREIGN KEY (`thread_idx`) REFERENCES `thread` (`thread_idx`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `post_ibfk_2` FOREIGN KEY (`user_idx`) REFERENCES `user` (`user_idx`) ON DELETE CASCADE ON UPDATE CASCADE;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
