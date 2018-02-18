! Copyright (C) 2008 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs calendar db db.sqlite db.tuples db.types
furnace.actions furnace.alloy furnace.boilerplate furnace.json
furnace.redirection html.forms http.server
http.server.dispatchers io.encodings.utf8 io.files json.reader
kernel namespaces regexp sequences validators ;
IN: velibwatch

TUPLE: report id station type timestamp username ;

report "REPORT"
{
    { "id" "ID" +db-assigned-id+ }
    { "station" "STATION" { VARCHAR 256 } }
    { "type" "TYPE" { VARCHAR 256 } }
    { "timestamp" "TIMESTAMP" TIMESTAMP }
    { "username" "USERNAME" { VARCHAR 256 } }
} define-persistent

TUPLE: velibwatch-app < dispatcher ;

: stations ( -- map )
    "vocab:velibwatch/stations.json" utf8
    file-contents json> ;

: stations-codes ( -- codes )
    stations [ "station" of "code" of ] map ;

: v-station ( str -- str )
    dup stations-codes member? [
        "Invalid station code : " prepend throw
    ] unless ;

: validate-report ( -- )
    {
        { "station" [ v-required v-station ] }
        { "type" [ "type" R/ ok|ko/ v-regexp ] }
        { "username" [ 255 v-max-length ] }
    } validate-params ;

: <home-action> ( -- action )
    <page-action>
        { velibwatch-app "home" } >>template ;

: <stations-action> ( -- action )
    <action>
         [ stations <json-content> ] >>display ;

: <consult-action> ( -- action )
    <page-action>
        [ report new select-tuples "reports" set-value ] >>init
        { velibwatch-app "consult" } >>template ;
: <detail-action> ( -- action )
    <home-action> ;
: <report-action> ( -- action )
    <home-action> ;
: <report-station-action> ( -- action )
    <page-action>
        [ { "" "ok" "ko" } "types" set-value ] >>init
        [ validate-report ] >>validate
        { velibwatch-app "report-station" } >>template
        [
            report new
            dup { "station" "type" "username" } to-object
            [ "" or ] change-username now >>timestamp
            insert-tuple "/consult" <redirect>
        ] >>submit ;

: <velibwatch-app> ( -- responder )
    velibwatch-app new-dispatcher
        <home-action> "" add-responder
        <stations-action> "stations.json" add-responder
        <consult-action> "consult" add-responder
        <detail-action> "detail" add-responder
        <report-action> "report" add-responder
        <report-station-action> "report-station" add-responder
    <boilerplate>
        { velibwatch-app "velibwatch" } >>template
;

! Deployment example
USING: db.sqlite furnace.alloy namespaces ;

: velibwatch-db ( -- db ) "velibwatch.db" <sqlite-db> ;

: init-velibwatch-db ( db -- )
    [ report ensure-table ] with-db ;

: run-velibwatch ( -- )
    <velibwatch-app>
        velibwatch-db
        [ init-velibwatch-db ] [ <alloy> ] bi
        main-responder set-global
    8081 local-server httpd drop
    { { 8081 80 } } port-remapping set-global
 ;

MAIN: run-velibwatch
