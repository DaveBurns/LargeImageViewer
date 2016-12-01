<?php
/**
 * Plugin Name: Large Image Viewer
 * Plugin URI: http://www.daveburnsphoto.com/liv/
 * Description: This plugin adds a shortcode so you can embed LargeImageViewers in your content
 * Version: 1.0.0
 * Author: Dave Burns
 * Author URI: http://www.daveburnsphoto.com
 * License: TBD
 */



if ( !function_exists( 'liv_log' ) ) {
    /**
     * liv_log: logs to WordPress debug.log in wp-content.
     *
     * Remember to set WP_DEBUG to true in wp-config.php
     *
     * @param $msg
     */
    function liv_log ( $msg )  {
        if ( true === WP_DEBUG ) {
            if ( is_array( $msg ) || is_object( $msg ) ) {
                error_log( 'LIV: ' . var_export( $msg, true ) );
            } else {
                error_log( 'LIV: ' . $msg );
            }
        }
    }
}


function register_liv_script() {
    $gmaps_url = 'https://maps.google.com/maps/api/js?v=3';
    $key = get_option( 'gmaps_api_key', false );
    if ( $key ) {
        $gmaps_url = $gmaps_url . '&key=' . $key;
    }
//    liv_log( 'GMaps URL after looking for key: ' . $gmaps_url );

    wp_register_script( 'google-maps', $gmaps_url, array(), false, false );
    wp_register_script( 'liv', plugins_url( '/js/jquery.largeimageviewer.js' , __FILE__ ), array( 'jquery-core', 'google-maps' ), '1.0', true );
}
add_action( 'init', 'register_liv_script' );


function liv_is_empty( $str )
{
    return trim( $str ) == '';
}


// Add Shortcode
/**
 * @param $atts
 * @return string
 */
function liv_shortcode( $atts ) {

    // normalize attribute keys to lowercase in case the user used upper case
    $atts = array_change_key_case( (array)$atts, CASE_LOWER );

    // Attributes
    $atts = shortcode_atts(
        array(
            'height' => '300',
            'tile_path' => '',
            'image_width' => '',
            'image_height' => '',
            'initial_x' => '',
            'initial_y' => '',
            'initial_zoom' => '',
            'background_color' => '',
            'title_top' => '',
            'title_bottom' => '',
            'copyright_text' => get_option( 'copyright_msg' , ''),
            'copyright_url'  => get_option( 'copyright_url' , ''),
            'fullscreen_control' => 'true',
            'no_css'         => get_option( 'no_css', '' ) == 1 ? 'true' : 'false',
            'debug' => 'true',
        ),
        $atts
    );

    liv_log( 'shortcode attributes below:' );
    liv_log( $atts );
//    liv_log( 'no_css: ' . ( get_option( 'no_css', 0 ) == 1 ? 'true' : 'false' ) );

    $atts_only_for_wp = array ( 'height' );

    // need a unique id number for the liv div in case there is more than one on a page
    static $liv_div_num = 0;
    $liv_div_id = 'liv_' . $liv_div_num;
    $liv_div_num++;

    // construct the liv options from the shortcode attributes
    $liv_options_json = '{';
    foreach ( $atts as $key => $value ) {
        if ( !liv_is_empty( $value ) ) {
            if ( !in_array( $key, $atts_only_for_wp ) ) {
                $liv_options_json .= $key . ": '" . $value . "',\n";
            }
        }
    }
    $liv_options_json .= '}';

    // create the unique JavaScript to attach LIV to this div and queue up the libraries
    wp_enqueue_script( 'liv' );
    $liv_doc_ready_func = 'jQuery( document ).ready( function() { jQuery( "#'. $liv_div_id . '").largeImageViewer(' . $liv_options_json . '); });';
    wp_add_inline_script( 'liv', $liv_doc_ready_func );

    $output  = "\n<div";
    $output .= ' class="liv_container"';
    $output .= ' id="' . $liv_div_id . '"';
    $output .= ' style="height: ' . $atts[ 'height' ] . 'px;"';
    $output .= "></div>\n\n";

    return $output;
}
add_shortcode( 'liv', 'liv_shortcode' );


// ******************** SETTINGS ****************************


add_action('admin_menu', 'liv_menu');
function liv_menu() {
    add_options_page( 'Large Image Viewer Settings',  // HTML title for settings page
                      'LIV Settings',                 // Menu text for Admin side menu
                      'administrator',                // Who can modify these settings
                      'liv_settings',                 // slug for settings page
                      'liv_settings_page' );          // function name to generate settings page
}


function liv_settings_page() {
    ?>
    <div class="wrap">
        <h2>Large Image Viewer Details</h2>
        <form method="post" action="options.php">
            <?php settings_fields( 'liv-settings' ); ?>
            <?php do_settings_sections( 'liv_settings' ); ?>
            <?php submit_button(); ?>
        </form>
    </div>
    <?php
}


add_action( 'admin_init', 'liv_settings' );
function liv_settings() {
    register_setting( 'liv-settings', 'gmaps_api_key' );
    register_setting( 'liv-settings', 'no_css' );
    register_setting( 'liv-settings', 'copyright_msg' );
    register_setting( 'liv-settings', 'copyright_url' );

    add_settings_section( 'liv-settings', 'Section One', 'liv_section_one_callback', 'liv_settings' );
    add_settings_field( 'liv-field-gmaps-api-key', 'Google Maps API Key', 'liv_field_gmaps_api_key_callback', 'liv_settings', 'liv-settings' );
    add_settings_field( 'liv-field-default-css',   'No default styles',   'liv_field_no_css_callback',        'liv_settings', 'liv-settings' );
    add_settings_field( 'liv-field-copyright-msg', 'Copyright message',   'liv_field_copyright_msg_callback', 'liv_settings', 'liv-settings' );
    add_settings_field( 'liv-field-copyright-url', 'Copyright URL',       'liv_field_copyright_url_callback', 'liv_settings', 'liv-settings' );
}


function liv_section_one_callback() {
    echo 'Some help text goes here.';
}


function liv_field_gmaps_api_key_callback() {
    $setting = esc_attr( get_option( 'gmaps_api_key' ) );
    echo "<input type='text' name='gmaps_api_key' value='$setting' style='width: 400px;'  title='Enter your unique Google Maps API Key here.'/>";
}


function liv_field_no_css_callback() {
    $setting = esc_attr( get_option( 'no_css' ) );
    echo "<input type='checkbox' name='no_css' value='1' " . checked( '1', $setting, false ) . " title='Check this box to exclude default styles.'/>";
}


function liv_field_copyright_msg_callback() {
    $setting = esc_attr( get_option( 'copyright_msg' ) );
    echo "<input type='text' name='copyright_msg' value='$setting' style='width: 400px;'  title='Enter your copyright message here.'/>";
}


function liv_field_copyright_url_callback() {
    $setting = esc_attr( get_option( 'copyright_url' ) );
    echo "<input type='text' name='copyright_url' value='$setting' style='width: 400px;'  title='Enter your copyright URL here.'/>";
}


