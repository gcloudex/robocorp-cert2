*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             RPA.HTTP
Library             RPA.Tables
Library             RPA.FileSystem
Library             RPA.PDF
Library             RPA.Archive
Library             RPA.Robocorp.Vault
Library             RPA.RobotLogListener


*** Variables ***
${PDF_TEMP_OUTPUT_DIRECTORY}=       ${OUTPUT_DIR}${/}receipts


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open the robot order website
    ${orders}=    Get orders
    Process orders    ${orders}
    [Teardown]    Close Browser


*** Keywords ***
Open the robot order website
    ${secret}=    Get Secret    rsbi
    #Open Available Browser    https://robotsparebinindustries.com/#/robot-order
    #Open Available Browser    ${secret}[url]    headless=True
    Open Available Browser    ${secret}[url]

Close the annoying modal
    Wait Until Element Is Visible    css:button.btn-dark
    Click Button    OK

Get orders
    Log    Getting orders
    Download    https://robotsparebinindustries.com/orders.csv    overwrite=True
    ${orders}=    Read table from CSV    orders.csv
    Log    Found columns: ${orders.columns}
    RETURN    ${orders}

Process orders
    [Arguments]    ${orders}
    Create Directory    ${PDF_TEMP_OUTPUT_DIRECTORY}
    FOR    ${row}    IN    @{orders}
        Log    Order: ${row}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        Mute Run On Failure    Submit the order
        Wait Until Keyword Succeeds    10x    3.0 sec    Submit the order
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Add the robot screenshot to the end of the receipt PDF file    ${screenshot}    ${pdf}    ${row}[Order number]
        Go to order another robot
    END
    Create a ZIP file of the receipts

Fill the form
    [Arguments]    ${order}
    Wait Until Element Is Visible    id:head
    Wait Until Element Is Visible    css:div.stacked
    Wait Until Element Is Visible    css:input.form-control
    Wait Until Element Is Visible    id:address
    Select From List By Value    head    ${order}[Head]
    Select Radio Button    body    ${order}[Body]
    Input Text    css:input.form-control    ${order}[Legs]
    Input Text    address    ${order}[Address]

Preview the robot
    Click Button    id:preview
    Wait Until Element Is Visible    id:robot-preview-image

Submit the order
    Click Button    id:order
    Wait Until Element Is Visible    id:receipt    3.0 sec

Store the receipt as a PDF file
    [Arguments]    ${orderNumber}
    Wait Until Element Is Visible    id:receipt
    ${order_receipt_html}=    Get Element Attribute    id:receipt    outerHTML
    Html To Pdf    ${order_receipt_html}    ${OUTPUT_DIR}${/}${orderNumber}.pdf
    RETURN    ${OUTPUT_DIR}${/}${orderNumber}.pdf

Take a screenshot of the robot
    [Arguments]    ${orderNumber}
    Screenshot    id:robot-preview-image    ${OUTPUT_DIR}${/}${orderNumber}.png
    RETURN    ${OUTPUT_DIR}${/}${orderNumber}.png

Add the robot screenshot to the end of the receipt PDF file
    [Arguments]    ${screenshot}    ${pdf}    ${orderNumber}
    ${files}=    Create List
    ...    ${pdf}
    ...    ${screenshot}:align=center
    Add Files To PDF    ${files}    ${PDF_TEMP_OUTPUT_DIRECTORY}${/}receipt-${orderNumber}.pdf
    Close All Pdfs

Go to order another robot
    Wait Until Element Is Visible    id:order-another
    Click Button    id:order-another

Create a ZIP file of the receipts
    ${zip_file_name}=    Set Variable    ${OUTPUT_DIR}/PDFs.zip
    Archive Folder With Zip
    ...    ${PDF_TEMP_OUTPUT_DIRECTORY}
    ...    ${zip_file_name}
