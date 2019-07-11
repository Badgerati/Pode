function Get-PodeContentType
{
    param (
        [Parameter()]
        [string]
        $Extension,

        [switch]
        $DefaultIsNull
    )

    if ([string]::IsNullOrWhiteSpace($Extension)) {
        $Extension = [string]::Empty
    }

    if (!$Extension.StartsWith('.')) {
        $Extension = ".$($Extension)"
    }

    # Sourced from https://github.com/samuelneff/MimeTypeMap
    switch ($Extension.ToLowerInvariant())
    {
        '.323' { return 'text/h323' }
        '.3g2' { return 'video/3gpp2' }
        '.3gp' { return 'video/3gpp' }
        '.3gp2' { return 'video/3gpp2' }
        '.3gpp' { return 'video/3gpp' }
        '.7z' { return 'application/x-7z-compressed' }
        '.aa' { return 'audio/audible' }
        '.aac' { return 'audio/aac' }
        '.aaf' { return 'application/octet-stream' }
        '.aax' { return 'audio/vnd.audible.aax' }
        '.ac3' { return 'audio/ac3' }
        '.aca' { return 'application/octet-stream' }
        '.accda' { return 'application/msaccess.addin' }
        '.accdb' { return 'application/msaccess' }
        '.accdc' { return 'application/msaccess.cab' }
        '.accde' { return 'application/msaccess' }
        '.accdr' { return 'application/msaccess.runtime' }
        '.accdt' { return 'application/msaccess' }
        '.accdw' { return 'application/msaccess.webapplication' }
        '.accft' { return 'application/msaccess.ftemplate' }
        '.acx' { return 'application/internet-property-stream' }
        '.addin' { return 'text/xml' }
        '.ade' { return 'application/msaccess' }
        '.adobebridge' { return 'application/x-bridge-url' }
        '.adp' { return 'application/msaccess' }
        '.adt' { return 'audio/vnd.dlna.adts' }
        '.adts' { return 'audio/aac' }
        '.afm' { return 'application/octet-stream' }
        '.ai' { return 'application/postscript' }
        '.aif' { return 'audio/aiff' }
        '.aifc' { return 'audio/aiff' }
        '.aiff' { return 'audio/aiff' }
        '.air' { return 'application/vnd.adobe.air-application-installer-package+zip' }
        '.amc' { return 'application/mpeg' }
        '.anx' { return 'application/annodex' }
        '.apk' { return 'application/vnd.android.package-archive' }
        '.application' { return 'application/x-ms-application' }
        '.art' { return 'image/x-jg' }
        '.asa' { return 'application/xml' }
        '.asax' { return 'application/xml' }
        '.ascx' { return 'application/xml' }
        '.asd' { return 'application/octet-stream' }
        '.asf' { return 'video/x-ms-asf' }
        '.ashx' { return 'application/xml' }
        '.asi' { return 'application/octet-stream' }
        '.asm' { return 'text/plain' }
        '.asmx' { return 'application/xml' }
        '.aspx' { return 'application/xml' }
        '.asr' { return 'video/x-ms-asf' }
        '.asx' { return 'video/x-ms-asf' }
        '.atom' { return 'application/atom+xml' }
        '.au' { return 'audio/basic' }
        '.avi' { return 'video/x-msvideo' }
        '.axa' { return 'audio/annodex' }
        '.axs' { return 'application/olescript' }
        '.axv' { return 'video/annodex' }
        '.bas' { return 'text/plain' }
        '.bcpio' { return 'application/x-bcpio' }
        '.bin' { return 'application/octet-stream' }
        '.bmp' { return 'image/bmp' }
        '.c' { return 'text/plain' }
        '.cab' { return 'application/octet-stream' }
        '.caf' { return 'audio/x-caf' }
        '.calx' { return 'application/vnd.ms-office.calx' }
        '.cat' { return 'application/vnd.ms-pki.seccat' }
        '.cc' { return 'text/plain' }
        '.cd' { return 'text/plain' }
        '.cdda' { return 'audio/aiff' }
        '.cdf' { return 'application/x-cdf' }
        '.cer' { return 'application/x-x509-ca-cert' }
        '.cfg' { return 'text/plain' }
        '.chm' { return 'application/octet-stream' }
        '.class' { return 'application/x-java-applet' }
        '.clp' { return 'application/x-msclip' }
        '.cmd' { return 'text/plain' }
        '.cmx' { return 'image/x-cmx' }
        '.cnf' { return 'text/plain' }
        '.cod' { return 'image/cis-cod' }
        '.config' { return 'application/xml' }
        '.contact' { return 'text/x-ms-contact' }
        '.coverage' { return 'application/xml' }
        '.cpio' { return 'application/x-cpio' }
        '.cpp' { return 'text/plain' }
        '.crd' { return 'application/x-mscardfile' }
        '.crl' { return 'application/pkix-crl' }
        '.crt' { return 'application/x-x509-ca-cert' }
        '.cs' { return 'text/plain' }
        '.csdproj' { return 'text/plain' }
        '.csh' { return 'application/x-csh' }
        '.csproj' { return 'text/plain' }
        '.css' { return 'text/css' }
        '.csv' { return 'text/csv' }
        '.cur' { return 'application/octet-stream' }
        '.cxx' { return 'text/plain' }
        '.dat' { return 'application/octet-stream' }
        '.datasource' { return 'application/xml' }
        '.dbproj' { return 'text/plain' }
        '.dcr' { return 'application/x-director' }
        '.def' { return 'text/plain' }
        '.deploy' { return 'application/octet-stream' }
        '.der' { return 'application/x-x509-ca-cert' }
        '.dgml' { return 'application/xml' }
        '.dib' { return 'image/bmp' }
        '.dif' { return 'video/x-dv' }
        '.dir' { return 'application/x-director' }
        '.disco' { return 'text/xml' }
        '.divx' { return 'video/divx' }
        '.dll' { return 'application/x-msdownload' }
        '.dll.config' { return 'text/xml' }
        '.dlm' { return 'text/dlm' }
        '.doc' { return 'application/msword' }
        '.docm' { return 'application/vnd.ms-word.document.macroEnabled.12' }
        '.docx' { return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' }
        '.dot' { return 'application/msword' }
        '.dotm' { return 'application/vnd.ms-word.template.macroEnabled.12' }
        '.dotx' { return 'application/vnd.openxmlformats-officedocument.wordprocessingml.template' }
        '.dsp' { return 'application/octet-stream' }
        '.dsw' { return 'text/plain' }
        '.dtd' { return 'text/xml' }
        '.dtsconfig' { return 'text/xml' }
        '.dv' { return 'video/x-dv' }
        '.dvi' { return 'application/x-dvi' }
        '.dwf' { return 'drawing/x-dwf' }
        '.dwg' { return 'application/acad' }
        '.dwp' { return 'application/octet-stream' }
        '.dxf' { return 'application/x-dxf' }
        '.dxr' { return 'application/x-director' }
        '.eml' { return 'message/rfc822' }
        '.emz' { return 'application/octet-stream' }
        '.eot' { return 'application/vnd.ms-fontobject' }
        '.eps' { return 'application/postscript' }
        '.etl' { return 'application/etl' }
        '.etx' { return 'text/x-setext' }
        '.evy' { return 'application/envoy' }
        '.exe' { return 'application/octet-stream' }
        '.exe.config' { return 'text/xml' }
        '.fdf' { return 'application/vnd.fdf' }
        '.fif' { return 'application/fractals' }
        '.filters' { return 'application/xml' }
        '.fla' { return 'application/octet-stream' }
        '.flac' { return 'audio/flac' }
        '.flr' { return 'x-world/x-vrml' }
        '.flv' { return 'video/x-flv' }
        '.fsscript' { return 'application/fsharp-script' }
        '.fsx' { return 'application/fsharp-script' }
        '.generictest' { return 'application/xml' }
        '.gif' { return 'image/gif' }
        '.gpx' { return 'application/gpx+xml' }
        '.group' { return 'text/x-ms-group' }
        '.gsm' { return 'audio/x-gsm' }
        '.gtar' { return 'application/x-gtar' }
        '.gz' { return 'application/x-gzip' }
        '.h' { return 'text/plain' }
        '.hdf' { return 'application/x-hdf' }
        '.hdml' { return 'text/x-hdml' }
        '.hhc' { return 'application/x-oleobject' }
        '.hhk' { return 'application/octet-stream' }
        '.hhp' { return 'application/octet-stream' }
        '.hlp' { return 'application/winhlp' }
        '.hpp' { return 'text/plain' }
        '.hqx' { return 'application/mac-binhex40' }
        '.hta' { return 'application/hta' }
        '.htc' { return 'text/x-component' }
        '.htm' { return 'text/html' }
        '.html' { return 'text/html' }
        '.htt' { return 'text/webviewhtml' }
        '.hxa' { return 'application/xml' }
        '.hxc' { return 'application/xml' }
        '.hxd' { return 'application/octet-stream' }
        '.hxe' { return 'application/xml' }
        '.hxf' { return 'application/xml' }
        '.hxh' { return 'application/octet-stream' }
        '.hxi' { return 'application/octet-stream' }
        '.hxk' { return 'application/xml' }
        '.hxq' { return 'application/octet-stream' }
        '.hxr' { return 'application/octet-stream' }
        '.hxs' { return 'application/octet-stream' }
        '.hxt' { return 'text/html' }
        '.hxv' { return 'application/xml' }
        '.hxw' { return 'application/octet-stream' }
        '.hxx' { return 'text/plain' }
        '.i' { return 'text/plain' }
        '.ico' { return 'image/x-icon' }
        '.ics' { return 'application/octet-stream' }
        '.idl' { return 'text/plain' }
        '.ief' { return 'image/ief' }
        '.iii' { return 'application/x-iphone' }
        '.inc' { return 'text/plain' }
        '.inf' { return 'application/octet-stream' }
        '.ini' { return 'text/plain' }
        '.inl' { return 'text/plain' }
        '.ins' { return 'application/x-internet-signup' }
        '.ipa' { return 'application/x-itunes-ipa' }
        '.ipg' { return 'application/x-itunes-ipg' }
        '.ipproj' { return 'text/plain' }
        '.ipsw' { return 'application/x-itunes-ipsw' }
        '.iqy' { return 'text/x-ms-iqy' }
        '.isp' { return 'application/x-internet-signup' }
        '.ite' { return 'application/x-itunes-ite' }
        '.itlp' { return 'application/x-itunes-itlp' }
        '.itms' { return 'application/x-itunes-itms' }
        '.itpc' { return 'application/x-itunes-itpc' }
        '.ivf' { return 'video/x-ivf' }
        '.jar' { return 'application/java-archive' }
        '.java' { return 'application/octet-stream' }
        '.jck' { return 'application/liquidmotion' }
        '.jcz' { return 'application/liquidmotion' }
        '.jfif' { return 'image/pjpeg' }
        '.jnlp' { return 'application/x-java-jnlp-file' }
        '.jpb' { return 'application/octet-stream' }
        '.jpe' { return 'image/jpeg' }
        '.jpeg' { return 'image/jpeg' }
        '.jpg' { return 'image/jpeg' }
        '.js' { return 'application/javascript' }
        '.json' { return 'application/json' }
        '.jsx' { return 'text/jscript' }
        '.jsxbin' { return 'text/plain' }
        '.latex' { return 'application/x-latex' }
        '.library-ms' { return 'application/windows-library+xml' }
        '.lit' { return 'application/x-ms-reader' }
        '.loadtest' { return 'application/xml' }
        '.lpk' { return 'application/octet-stream' }
        '.lsf' { return 'video/x-la-asf' }
        '.lst' { return 'text/plain' }
        '.lsx' { return 'video/x-la-asf' }
        '.lzh' { return 'application/octet-stream' }
        '.m13' { return 'application/x-msmediaview' }
        '.m14' { return 'application/x-msmediaview' }
        '.m1v' { return 'video/mpeg' }
        '.m2t' { return 'video/vnd.dlna.mpeg-tts' }
        '.m2ts' { return 'video/vnd.dlna.mpeg-tts' }
        '.m2v' { return 'video/mpeg' }
        '.m3u' { return 'audio/x-mpegurl' }
        '.m3u8' { return 'audio/x-mpegurl' }
        '.m4a' { return 'audio/m4a' }
        '.m4b' { return 'audio/m4b' }
        '.m4p' { return 'audio/m4p' }
        '.m4r' { return 'audio/x-m4r' }
        '.m4v' { return 'video/x-m4v' }
        '.mac' { return 'image/x-macpaint' }
        '.mak' { return 'text/plain' }
        '.man' { return 'application/x-troff-man' }
        '.manifest' { return 'application/x-ms-manifest' }
        '.map' { return 'text/plain' }
        '.master' { return 'application/xml' }
        '.mbox' { return 'application/mbox' }
        '.mda' { return 'application/msaccess' }
        '.mdb' { return 'application/x-msaccess' }
        '.mde' { return 'application/msaccess' }
        '.mdp' { return 'application/octet-stream' }
        '.me' { return 'application/x-troff-me' }
        '.mfp' { return 'application/x-shockwave-flash' }
        '.mht' { return 'message/rfc822' }
        '.mhtml' { return 'message/rfc822' }
        '.mid' { return 'audio/mid' }
        '.midi' { return 'audio/mid' }
        '.mix' { return 'application/octet-stream' }
        '.mk' { return 'text/plain' }
        '.mk3d' { return 'video/x-matroska-3d' }
        '.mka' { return 'audio/x-matroska' }
        '.mkv' { return 'video/x-matroska' }
        '.mmf' { return 'application/x-smaf' }
        '.mno' { return 'text/xml' }
        '.mny' { return 'application/x-msmoney' }
        '.mod' { return 'video/mpeg' }
        '.mov' { return 'video/quicktime' }
        '.movie' { return 'video/x-sgi-movie' }
        '.mp2' { return 'video/mpeg' }
        '.mp2v' { return 'video/mpeg' }
        '.mp3' { return 'audio/mpeg' }
        '.mp4' { return 'video/mp4' }
        '.mp4v' { return 'video/mp4' }
        '.mpa' { return 'video/mpeg' }
        '.mpe' { return 'video/mpeg' }
        '.mpeg' { return 'video/mpeg' }
        '.mpf' { return 'application/vnd.ms-mediapackage' }
        '.mpg' { return 'video/mpeg' }
        '.mpp' { return 'application/vnd.ms-project' }
        '.mpv2' { return 'video/mpeg' }
        '.mqv' { return 'video/quicktime' }
        '.ms' { return 'application/x-troff-ms' }
        '.msg' { return 'application/vnd.ms-outlook' }
        '.msi' { return 'application/octet-stream' }
        '.mso' { return 'application/octet-stream' }
        '.mts' { return 'video/vnd.dlna.mpeg-tts' }
        '.mtx' { return 'application/xml' }
        '.mvb' { return 'application/x-msmediaview' }
        '.mvc' { return 'application/x-miva-compiled' }
        '.mxp' { return 'application/x-mmxp' }
        '.nc' { return 'application/x-netcdf' }
        '.nsc' { return 'video/x-ms-asf' }
        '.nws' { return 'message/rfc822' }
        '.ocx' { return 'application/octet-stream' }
        '.oda' { return 'application/oda' }
        '.odb' { return 'application/vnd.oasis.opendocument.database' }
        '.odc' { return 'application/vnd.oasis.opendocument.chart' }
        '.odf' { return 'application/vnd.oasis.opendocument.formula' }
        '.odg' { return 'application/vnd.oasis.opendocument.graphics' }
        '.odh' { return 'text/plain' }
        '.odi' { return 'application/vnd.oasis.opendocument.image' }
        '.odl' { return 'text/plain' }
        '.odm' { return 'application/vnd.oasis.opendocument.text-master' }
        '.odp' { return 'application/vnd.oasis.opendocument.presentation' }
        '.ods' { return 'application/vnd.oasis.opendocument.spreadsheet' }
        '.odt' { return 'application/vnd.oasis.opendocument.text' }
        '.oga' { return 'audio/ogg' }
        '.ogg' { return 'audio/ogg' }
        '.ogv' { return 'video/ogg' }
        '.ogx' { return 'application/ogg' }
        '.one' { return 'application/onenote' }
        '.onea' { return 'application/onenote' }
        '.onepkg' { return 'application/onenote' }
        '.onetmp' { return 'application/onenote' }
        '.onetoc' { return 'application/onenote' }
        '.onetoc2' { return 'application/onenote' }
        '.opus' { return 'audio/ogg' }
        '.orderedtest' { return 'application/xml' }
        '.osdx' { return 'application/opensearchdescription+xml' }
        '.otf' { return 'application/font-sfnt' }
        '.otg' { return 'application/vnd.oasis.opendocument.graphics-template' }
        '.oth' { return 'application/vnd.oasis.opendocument.text-web' }
        '.otp' { return 'application/vnd.oasis.opendocument.presentation-template' }
        '.ots' { return 'application/vnd.oasis.opendocument.spreadsheet-template' }
        '.ott' { return 'application/vnd.oasis.opendocument.text-template' }
        '.oxt' { return 'application/vnd.openofficeorg.extension' }
        '.p10' { return 'application/pkcs10' }
        '.p12' { return 'application/x-pkcs12' }
        '.p7b' { return 'application/x-pkcs7-certificates' }
        '.p7c' { return 'application/pkcs7-mime' }
        '.p7m' { return 'application/pkcs7-mime' }
        '.p7r' { return 'application/x-pkcs7-certreqresp' }
        '.p7s' { return 'application/pkcs7-signature' }
        '.pbm' { return 'image/x-portable-bitmap' }
        '.pcast' { return 'application/x-podcast' }
        '.pct' { return 'image/pict' }
        '.pcx' { return 'application/octet-stream' }
        '.pcz' { return 'application/octet-stream' }
        '.pdf' { return 'application/pdf' }
        '.pfb' { return 'application/octet-stream' }
        '.pfm' { return 'application/octet-stream' }
        '.pfx' { return 'application/x-pkcs12' }
        '.pgm' { return 'image/x-portable-graymap' }
        '.pic' { return 'image/pict' }
        '.pict' { return 'image/pict' }
        '.pkgdef' { return 'text/plain' }
        '.pkgundef' { return 'text/plain' }
        '.pko' { return 'application/vnd.ms-pki.pko' }
        '.pls' { return 'audio/scpls' }
        '.pma' { return 'application/x-perfmon' }
        '.pmc' { return 'application/x-perfmon' }
        '.pml' { return 'application/x-perfmon' }
        '.pmr' { return 'application/x-perfmon' }
        '.pmw' { return 'application/x-perfmon' }
        '.png' { return 'image/png' }
        '.pnm' { return 'image/x-portable-anymap' }
        '.pnt' { return 'image/x-macpaint' }
        '.pntg' { return 'image/x-macpaint' }
        '.pnz' { return 'image/png' }
        '.pode' { return 'application/PowerShell' }
        '.pot' { return 'application/vnd.ms-powerpoint' }
        '.potm' { return 'application/vnd.ms-powerpoint.template.macroEnabled.12' }
        '.potx' { return 'application/vnd.openxmlformats-officedocument.presentationml.template' }
        '.ppa' { return 'application/vnd.ms-powerpoint' }
        '.ppam' { return 'application/vnd.ms-powerpoint.addin.macroEnabled.12' }
        '.ppm' { return 'image/x-portable-pixmap' }
        '.pps' { return 'application/vnd.ms-powerpoint' }
        '.ppsm' { return 'application/vnd.ms-powerpoint.slideshow.macroEnabled.12' }
        '.ppsx' { return 'application/vnd.openxmlformats-officedocument.presentationml.slideshow' }
        '.ppt' { return 'application/vnd.ms-powerpoint' }
        '.pptm' { return 'application/vnd.ms-powerpoint.presentation.macroEnabled.12' }
        '.pptx' { return 'application/vnd.openxmlformats-officedocument.presentationml.presentation' }
        '.prf' { return 'application/pics-rules' }
        '.prm' { return 'application/octet-stream' }
        '.prx' { return 'application/octet-stream' }
        '.ps' { return 'application/postscript' }
        '.ps1' { return 'application/PowerShell' }
        '.psc1' { return 'application/PowerShell' }
        '.psd1' { return 'application/PowerShell' }
        '.psm1' { return 'application/PowerShell' }
        '.psd' { return 'application/octet-stream' }
        '.psess' { return 'application/xml' }
        '.psm' { return 'application/octet-stream' }
        '.psp' { return 'application/octet-stream' }
        '.pst' { return 'application/vnd.ms-outlook' }
        '.pub' { return 'application/x-mspublisher' }
        '.pwz' { return 'application/vnd.ms-powerpoint' }
        '.qht' { return 'text/x-html-insertion' }
        '.qhtm' { return 'text/x-html-insertion' }
        '.qt' { return 'video/quicktime' }
        '.qti' { return 'image/x-quicktime' }
        '.qtif' { return 'image/x-quicktime' }
        '.qtl' { return 'application/x-quicktimeplayer' }
        '.qxd' { return 'application/octet-stream' }
        '.ra' { return 'audio/x-pn-realaudio' }
        '.ram' { return 'audio/x-pn-realaudio' }
        '.rar' { return 'application/x-rar-compressed' }
        '.ras' { return 'image/x-cmu-raster' }
        '.rat' { return 'application/rat-file' }
        '.rc' { return 'text/plain' }
        '.rc2' { return 'text/plain' }
        '.rct' { return 'text/plain' }
        '.rdlc' { return 'application/xml' }
        '.reg' { return 'text/plain' }
        '.resx' { return 'application/xml' }
        '.rf' { return 'image/vnd.rn-realflash' }
        '.rgb' { return 'image/x-rgb' }
        '.rgs' { return 'text/plain' }
        '.rm' { return 'application/vnd.rn-realmedia' }
        '.rmi' { return 'audio/mid' }
        '.rmp' { return 'application/vnd.rn-rn_music_package' }
        '.roff' { return 'application/x-troff' }
        '.rpm' { return 'audio/x-pn-realaudio-plugin' }
        '.rqy' { return 'text/x-ms-rqy' }
        '.rtf' { return 'application/rtf' }
        '.rtx' { return 'text/richtext' }
        '.rvt' { return 'application/octet-stream' }
        '.ruleset' { return 'application/xml' }
        '.s' { return 'text/plain' }
        '.safariextz' { return 'application/x-safari-safariextz' }
        '.scd' { return 'application/x-msschedule' }
        '.scr' { return 'text/plain' }
        '.sct' { return 'text/scriptlet' }
        '.sd2' { return 'audio/x-sd2' }
        '.sdp' { return 'application/sdp' }
        '.sea' { return 'application/octet-stream' }
        '.searchconnector-ms' { return 'application/windows-search-connector+xml' }
        '.setpay' { return 'application/set-payment-initiation' }
        '.setreg' { return 'application/set-registration-initiation' }
        '.settings' { return 'application/xml' }
        '.sgimb' { return 'application/x-sgimb' }
        '.sgml' { return 'text/sgml' }
        '.sh' { return 'application/x-sh' }
        '.shar' { return 'application/x-shar' }
        '.shtml' { return 'text/html' }
        '.sit' { return 'application/x-stuffit' }
        '.sitemap' { return 'application/xml' }
        '.skin' { return 'application/xml' }
        '.skp' { return 'application/x-koan' }
        '.sldm' { return 'application/vnd.ms-powerpoint.slide.macroEnabled.12' }
        '.sldx' { return 'application/vnd.openxmlformats-officedocument.presentationml.slide' }
        '.slk' { return 'application/vnd.ms-excel' }
        '.sln' { return 'text/plain' }
        '.slupkg-ms' { return 'application/x-ms-license' }
        '.smd' { return 'audio/x-smd' }
        '.smi' { return 'application/octet-stream' }
        '.smx' { return 'audio/x-smd' }
        '.smz' { return 'audio/x-smd' }
        '.snd' { return 'audio/basic' }
        '.snippet' { return 'application/xml' }
        '.snp' { return 'application/octet-stream' }
        '.sol' { return 'text/plain' }
        '.sor' { return 'text/plain' }
        '.spc' { return 'application/x-pkcs7-certificates' }
        '.spl' { return 'application/futuresplash' }
        '.spx' { return 'audio/ogg' }
        '.src' { return 'application/x-wais-source' }
        '.srf' { return 'text/plain' }
        '.ssisdeploymentmanifest' { return 'text/xml' }
        '.ssm' { return 'application/streamingmedia' }
        '.sst' { return 'application/vnd.ms-pki.certstore' }
        '.stl' { return 'application/vnd.ms-pki.stl' }
        '.sv4cpio' { return 'application/x-sv4cpio' }
        '.sv4crc' { return 'application/x-sv4crc' }
        '.svc' { return 'application/xml' }
        '.svg' { return 'image/svg+xml' }
        '.swf' { return 'application/x-shockwave-flash' }
        '.step' { return 'application/step' }
        '.stp' { return 'application/step' }
        '.t' { return 'application/x-troff' }
        '.tar' { return 'application/x-tar' }
        '.tcl' { return 'application/x-tcl' }
        '.testrunconfig' { return 'application/xml' }
        '.testsettings' { return 'application/xml' }
        '.tex' { return 'application/x-tex' }
        '.texi' { return 'application/x-texinfo' }
        '.texinfo' { return 'application/x-texinfo' }
        '.tgz' { return 'application/x-compressed' }
        '.thmx' { return 'application/vnd.ms-officetheme' }
        '.thn' { return 'application/octet-stream' }
        '.tif' { return 'image/tiff' }
        '.tiff' { return 'image/tiff' }
        '.tlh' { return 'text/plain' }
        '.tli' { return 'text/plain' }
        '.toc' { return 'application/octet-stream' }
        '.tr' { return 'application/x-troff' }
        '.trm' { return 'application/x-msterminal' }
        '.trx' { return 'application/xml' }
        '.ts' { return 'video/vnd.dlna.mpeg-tts' }
        '.tsv' { return 'text/tab-separated-values' }
        '.ttf' { return 'application/font-sfnt' }
        '.tts' { return 'video/vnd.dlna.mpeg-tts' }
        '.txt' { return 'text/plain' }
        '.u32' { return 'application/octet-stream' }
        '.uls' { return 'text/iuls' }
        '.user' { return 'text/plain' }
        '.ustar' { return 'application/x-ustar' }
        '.vb' { return 'text/plain' }
        '.vbdproj' { return 'text/plain' }
        '.vbk' { return 'video/mpeg' }
        '.vbproj' { return 'text/plain' }
        '.vbs' { return 'text/vbscript' }
        '.vcf' { return 'text/x-vcard' }
        '.vcproj' { return 'application/xml' }
        '.vcs' { return 'text/plain' }
        '.vcxproj' { return 'application/xml' }
        '.vddproj' { return 'text/plain' }
        '.vdp' { return 'text/plain' }
        '.vdproj' { return 'text/plain' }
        '.vdx' { return 'application/vnd.ms-visio.viewer' }
        '.vml' { return 'text/xml' }
        '.vscontent' { return 'application/xml' }
        '.vsct' { return 'text/xml' }
        '.vsd' { return 'application/vnd.visio' }
        '.vsi' { return 'application/ms-vsi' }
        '.vsix' { return 'application/vsix' }
        '.vsixlangpack' { return 'text/xml' }
        '.vsixmanifest' { return 'text/xml' }
        '.vsmdi' { return 'application/xml' }
        '.vspscc' { return 'text/plain' }
        '.vss' { return 'application/vnd.visio' }
        '.vsscc' { return 'text/plain' }
        '.vssettings' { return 'text/xml' }
        '.vssscc' { return 'text/plain' }
        '.vst' { return 'application/vnd.visio' }
        '.vstemplate' { return 'text/xml' }
        '.vsto' { return 'application/x-ms-vsto' }
        '.vsw' { return 'application/vnd.visio' }
        '.vsx' { return 'application/vnd.visio' }
        '.vtx' { return 'application/vnd.visio' }
        '.wasm' { return 'application/wasm' }
        '.wav' { return 'audio/wav' }
        '.wave' { return 'audio/wav' }
        '.wax' { return 'audio/x-ms-wax' }
        '.wbk' { return 'application/msword' }
        '.wbmp' { return 'image/vnd.wap.wbmp' }
        '.wcm' { return 'application/vnd.ms-works' }
        '.wdb' { return 'application/vnd.ms-works' }
        '.wdp' { return 'image/vnd.ms-photo' }
        '.webarchive' { return 'application/x-safari-webarchive' }
        '.webm' { return 'video/webm' }
        '.webp' { return 'image/webp' }
        '.webtest' { return 'application/xml' }
        '.wiq' { return 'application/xml' }
        '.wiz' { return 'application/msword' }
        '.wks' { return 'application/vnd.ms-works' }
        '.wlmp' { return 'application/wlmoviemaker' }
        '.wlpginstall' { return 'application/x-wlpg-detect' }
        '.wlpginstall3' { return 'application/x-wlpg3-detect' }
        '.wm' { return 'video/x-ms-wm' }
        '.wma' { return 'audio/x-ms-wma' }
        '.wmd' { return 'application/x-ms-wmd' }
        '.wmf' { return 'application/x-msmetafile' }
        '.wml' { return 'text/vnd.wap.wml' }
        '.wmlc' { return 'application/vnd.wap.wmlc' }
        '.wmls' { return 'text/vnd.wap.wmlscript' }
        '.wmlsc' { return 'application/vnd.wap.wmlscriptc' }
        '.wmp' { return 'video/x-ms-wmp' }
        '.wmv' { return 'video/x-ms-wmv' }
        '.wmx' { return 'video/x-ms-wmx' }
        '.wmz' { return 'application/x-ms-wmz' }
        '.woff' { return 'application/font-woff' }
        '.woff2' { return 'application/font-woff2' }
        '.wpl' { return 'application/vnd.ms-wpl' }
        '.wps' { return 'application/vnd.ms-works' }
        '.wri' { return 'application/x-mswrite' }
        '.wrl' { return 'x-world/x-vrml' }
        '.wrz' { return 'x-world/x-vrml' }
        '.wsc' { return 'text/scriptlet' }
        '.wsdl' { return 'text/xml' }
        '.wvx' { return 'video/x-ms-wvx' }
        '.x' { return 'application/directx' }
        '.xaf' { return 'x-world/x-vrml' }
        '.xaml' { return 'application/xaml+xml' }
        '.xap' { return 'application/x-silverlight-app' }
        '.xbap' { return 'application/x-ms-xbap' }
        '.xbm' { return 'image/x-xbitmap' }
        '.xdr' { return 'text/plain' }
        '.xht' { return 'application/xhtml+xml' }
        '.xhtml' { return 'application/xhtml+xml' }
        '.xla' { return 'application/vnd.ms-excel' }
        '.xlam' { return 'application/vnd.ms-excel.addin.macroEnabled.12' }
        '.xlc' { return 'application/vnd.ms-excel' }
        '.xld' { return 'application/vnd.ms-excel' }
        '.xlk' { return 'application/vnd.ms-excel' }
        '.xll' { return 'application/vnd.ms-excel' }
        '.xlm' { return 'application/vnd.ms-excel' }
        '.xls' { return 'application/vnd.ms-excel' }
        '.xlsb' { return 'application/vnd.ms-excel.sheet.binary.macroEnabled.12' }
        '.xlsm' { return 'application/vnd.ms-excel.sheet.macroEnabled.12' }
        '.xlsx' { return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
        '.xlt' { return 'application/vnd.ms-excel' }
        '.xltm' { return 'application/vnd.ms-excel.template.macroEnabled.12' }
        '.xltx' { return 'application/vnd.openxmlformats-officedocument.spreadsheetml.template' }
        '.xlw' { return 'application/vnd.ms-excel' }
        '.xml' { return 'text/xml' }
        '.xmp' { return 'application/octet-stream' }
        '.xmta' { return 'application/xml' }
        '.xof' { return 'x-world/x-vrml' }
        '.xoml' { return 'text/plain' }
        '.xpm' { return 'image/x-xpixmap' }
        '.xps' { return 'application/vnd.ms-xpsdocument' }
        '.xrm-ms' { return 'text/xml' }
        '.xsc' { return 'application/xml' }
        '.xsd' { return 'text/xml' }
        '.xsf' { return 'text/xml' }
        '.xsl' { return 'text/xml' }
        '.xslt' { return 'text/xml' }
        '.xsn' { return 'application/octet-stream' }
        '.xss' { return 'application/xml' }
        '.xspf' { return 'application/xspf+xml' }
        '.xtp' { return 'application/octet-stream' }
        '.xwd' { return 'image/x-xwindowdump' }
        '.yaml' { return 'application/x-yaml' }
        '.yml' { return 'application/x-yaml' }
        '.z' { return 'application/x-compress' }
        '.zip' { return 'application/zip' }
        default { return (Resolve-PodeValue -Check $DefaultIsNull -TrueValue $null -FalseValue 'text/plain') }
    }
}

function Get-PodeStatusDescription
{
    param (
        [Parameter()]
        [int]
        $StatusCode
    )

    switch ($StatusCode)
    {
        100 { return 'Continue' }
        101 { return 'Switching Protocols' }
        102 { return 'Processing' }
        103 { return 'Early Hints' }
        200 { return 'OK' }
        201 { return 'Created' }
        202 { return 'Accepted' }
        203 { return 'Non-Authoritative Information' }
        204 { return 'No Content' }
        205 { return 'Reset Content' }
        206 { return 'Partial Content' }
        207 { return 'Multi-Status' }
        208 { return 'Already Reported' }
        226 { return 'IM Used' }
        300 { return 'Multiple Choices' }
        301 { return 'Moved Permanently' }
        302 { return 'Found' }
        303 { return 'See Other' }
        304 { return 'Not Modified' }
        305 { return 'Use Proxy' }
        306 { return 'Switch Proxy' }
        307 { return 'Temporary Redirect' }
        308 { return 'Permanent Redirect' }
        400 { return 'Bad Request' }
        401 { return 'Unauthorized' }
        402 { return 'Payment Required' }
        403 { return 'Forbidden' }
        404 { return 'Not Found' }
        405 { return 'Method Not Allowed' }
        406 { return 'Not Acceptable' }
        407 { return 'Proxy Authentication Required' }
        408 { return 'Request Timeout' }
        409 { return 'Conflict' }
        410 { return 'Gone' }
        411 { return 'Length Required' }
        412 { return 'Precondition Failed' }
        413 { return 'Payload Too Large' }
        414 { return 'URI Too Long' }
        415 { return 'Unsupported Media Type' }
        416 { return 'Range Not Satisfiable' }
        417 { return 'Expectation Failed' }
        418 { return "I'm a Teapot" }
        419 { return 'Page Expired' }
        420 { return 'Enhance Your Calm' }
        421 { return 'Misdirected Request' }
        422 { return 'Unprocessable Entity' }
        423 { return 'Locked' }
        424 { return 'Failed Dependency' }
        426 { return 'Upgrade Required' }
        428 { return 'Precondition Required' }
        429 { return 'Too Many Requests' }
        431 { return 'Request Header Fields Too Large' }
        440 { return 'Login Time-out' }
        450 { return 'Blocked by Windows Parental Controls' }
        451 { return 'Unavailable For Legal Reasons' }
        500 { return 'Internal Server Error' }
        501 { return 'Not Implemented' }
        502 { return 'Bad Gateway' }
        503 { return 'Service Unavailable' }
        504 { return 'Gateway Timeout' }
        505 { return 'HTTP Version Not Supported' }
        506 { return 'Variant Also Negotiates' }
        507 { return 'Insufficient Storage' }
        508 { return 'Loop Detected' }
        510 { return 'Not Extended' }
        511 { return 'Network Authentication Required' }
        526 { return 'Invalid SSL Certificate' }
        default { return ([string]::Empty) }
    }
}