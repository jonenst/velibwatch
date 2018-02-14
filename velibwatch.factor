! Copyright (C) 2008 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs db db.sqlite db.tuples db.types
furnace.actions furnace.alloy furnace.boilerplate
furnace.redirection html.forms http.server
http.server.dispatchers io.encodings.utf8 io.files json.reader
kernel namespaces regexp sequences validators ;
IN: velibwatch

TUPLE: report id station type username ;

report "REPORT"
{
    { "id" "ID" +db-assigned-id+ }
    { "station" "STATION" { VARCHAR 256 } }
    { "type" "TYPE" { VARCHAR 256 } }
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
        [ validate-report ] >>validate
        { velibwatch-app "report-station" } >>template
        [
            report new
            dup { "station" "type" "username" } to-object
            [ "" or ] change-username
            insert-tuple "/consult" <redirect>
        ] >>submit ;

! Deployment example
USING: db.sqlite furnace.alloy namespaces ;

: velibwatch-db ( -- db ) "velibwatch.db" <sqlite-db> ;

: <velibwatch-app> ( -- responder )
    velibwatch-db [ report ensure-table ] with-db
    velibwatch-app new-dispatcher
        <home-action> "" add-responder
        <consult-action> "consult" add-responder
        <detail-action> "detail" add-responder
        <report-action> "report" add-responder
        <report-station-action> "report-station" add-responder
    <boilerplate>
        { velibwatch-app "velibwatch" } >>template
;


: run-velibwatch ( -- )
    <velibwatch-app>
        velibwatch-db <alloy>
        main-responder set-global
    8080 httpd drop ;

MAIN: run-velibwatch
