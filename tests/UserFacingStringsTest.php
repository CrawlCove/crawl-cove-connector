<?php

use PHPUnit\Framework\TestCase;

/**
 * House style for text a site owner or the desktop app user reads: no em
 * dashes in string literals (admin page, REST messages, plugin header).
 * Comments are exempt. A lone dash is the empty-cell placeholder in the
 * change log table, a WordPress core convention rather than prose.
 */
class UserFacingStringsTest extends TestCase {

	private function plugin_php_files() {
		$root  = dirname( __DIR__ );
		$files = array( $root . '/crawl-cove-connector.php', $root . '/uninstall.php' );
		foreach ( array( 'admin', 'includes' ) as $dir ) {
			$files = array_merge( $files, glob( $root . '/' . $dir . '/*.php' ) );
		}
		return $files;
	}

	public function test_string_literals_carry_no_em_dashes() {
		$dash  = "\u{2014}";
		$found = array();
		foreach ( $this->plugin_php_files() as $file ) {
			foreach ( token_get_all( (string) file_get_contents( $file ) ) as $token ) {
				if ( ! is_array( $token ) || false === strpos( $token[1], $dash ) ) {
					continue;
				}
				if ( T_CONSTANT_ENCAPSED_STRING === $token[0] && "'" . $dash . "'" === $token[1] ) {
					continue;
				}
				if ( in_array( $token[0], array( T_CONSTANT_ENCAPSED_STRING, T_ENCAPSED_AND_WHITESPACE, T_INLINE_HTML ), true ) ) {
					$found[] = basename( $file ) . ':' . $token[2];
				}
			}
		}
		$this->assertSame( array(), $found );
	}

	public function test_plugin_header_description_carries_no_em_dash() {
		$main = (string) file_get_contents( dirname( __DIR__ ) . '/crawl-cove-connector.php' );
		preg_match( '/^\s*\*\s*Description:\s*(.+)$/m', $main, $description );

		$this->assertNotEmpty( $description );
		$this->assertStringNotContainsString( "\u{2014}", $description[1] );
	}
}
