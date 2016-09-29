#!/usr/local/bin/perl -w
#script to auto login to a cisco switch or router

use Net::Telnet::Cisco ();


my $host="10.10.1.1";
my  $username = "root";
my  $passwd = "BABABU";


print "Loging to $host \n";


$t = Net::Telnet::Cisco -> new (
Timeout => 10,
Input_log => "output.log");
$t->open($host);
$t->waitfor('/Password:/');
$t->print($passwd);
$t->login($username,$pass);
$t->autopage;
$t->always_waitfor_prompt;
$t->cmd("show ver");
$t->close;
