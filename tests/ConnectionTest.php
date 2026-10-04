<?php

use PHPUnit\Framework\TestCase;

class ConnectionTest extends TestCase {

	protected function setUp(): void {
		cc_reset_wp();
	}

	public function test_nothing_recorded_until_a_call_is_touched() {
		$this->assertNull( CCC_Connection::last() );
	}

	public function test_touch_records_time_user_and_route() {
		$this->assertTrue( CCC_Connection::touch( 'lewis', '/wp-json/crawlcove/v1/status', 1000 ) );
		$this->assertSame(
			array(
				'time'  => 1000,
				'user'  => 'lewis',
				'route' => '/wp-json/crawlcove/v1/status',
			),
			CCC_Connection::last()
		);
	}

	public function test_writes_are_throttled_to_once_a_minute_per_user() {
		CCC_Connection::touch( 'lewis', '/a', 1000 );
		$this->assertFalse( CCC_Connection::touch( 'lewis', '/b', 1000 + CCC_Connection::INTERVAL - 1 ) );
		$this->assertSame( '/a', CCC_Connection::last()['route'] );
		$this->assertTrue( CCC_Connection::touch( 'lewis', '/b', 1000 + CCC_Connection::INTERVAL ) );
		$this->assertSame( '/b', CCC_Connection::last()['route'] );
	}

	public function test_a_different_user_inside_the_window_is_still_recorded() {
		CCC_Connection::touch( 'lewis', '/a', 1000 );
		$this->assertTrue( CCC_Connection::touch( 'bloo', '/a', 1001 ) );
		$this->assertSame( 'bloo', CCC_Connection::last()['user'] );
	}

	public function test_corrupt_option_reads_as_not_connected() {
		update_option( CCC_Connection::OPTION, 'garbage' );
		$this->assertNull( CCC_Connection::last() );
		update_option( CCC_Connection::OPTION, array( 'user' => 'x' ) );
		$this->assertNull( CCC_Connection::last() );
	}
}
