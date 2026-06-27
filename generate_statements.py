import os
from reportlab.lib.pagesizes import A4
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors

# Output folder for the PDFs
OUTPUT_DIR = "/Users/eduardoledo/Development/personal/audiobook_player/modelos_resumenes_bancarios"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def create_card_statement(filename, bank_name, card_brand, primary_color, secondary_color, client_name, card_num, details, transactions):
    """
    Generates a credit card statement PDF (Visa or Mastercard).
    """
    pdf_path = os.path.join(OUTPUT_DIR, filename)
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=A4,
        rightMargin=30,
        leftMargin=30,
        topMargin=30,
        bottomMargin=30
    )
    
    story = []
    styles = getSampleStyleSheet()
    
    # Custom styles
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=18,
        textColor=colors.HexColor(primary_color),
        spaceAfter=5
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10,
        textColor=colors.HexColor('#555555'),
        spaceAfter=15
    )
    
    header_label = ParagraphStyle(
        'HLabel',
        fontName='Helvetica-Bold',
        fontSize=9,
        textColor=colors.white
    )
    
    header_val = ParagraphStyle(
        'HVal',
        fontName='Helvetica',
        fontSize=9,
        textColor=colors.white
    )
    
    cell_style = ParagraphStyle(
        'Cell',
        fontName='Helvetica',
        fontSize=8,
        leading=10
    )
    
    cell_bold = ParagraphStyle(
        'CellBold',
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10
    )
    
    cell_right = ParagraphStyle(
        'CellRight',
        fontName='Helvetica',
        fontSize=8,
        alignment=2 # Right aligned
    )
    
    cell_right_bold = ParagraphStyle(
        'CellRightBold',
        fontName='Helvetica-Bold',
        fontSize=8,
        alignment=2
    )

    # 1. Header Banner
    header_data = [
        [
            Paragraph(f"<b>{bank_name.upper()}</b> | {card_brand.upper()}", header_label),
            Paragraph(f"<b>RESUMEN DE CUENTA DE TARJETA DE CRÉDITO</b>", header_label)
        ],
        [
            Paragraph(f"<b>Titular:</b> {client_name}<br/><b>Dirección:</b> Av. del Libertador 1200, CABA<br/><b>CUIT:</b> 20-30456789-2", header_val),
            Paragraph(f"<b>Tarjeta Nro:</b> {card_num}<br/><b>Emisión:</b> {details['cierre_actual']}<br/><b>Moneda:</b> ARS / USD", header_val)
        ]
    ]
    
    # 535 total A4 printable width (595 - 60)
    header_table = Table(header_data, colWidths=[270, 265])
    header_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor(primary_color)),
        ('TEXTCOLOR', (0,0), (-1,-1), colors.white),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 12),
        ('RIGHTPADDING', (0,0), (-1,-1), 12),
        ('LINEBELOW', (0,0), (-1,0), 1, colors.HexColor(secondary_color)),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 15))
    
    # 2. Key Information Table (Cierre, Vencimiento, Pagos)
    summary_headers = ["CIERRE ANTERIOR", "CIERRE ACTUAL", "VENCIMIENTO", "PAGO MÍNIMO", "PAGO TOTAL ARS", "PAGO TOTAL USD"]
    summary_values = [
        details['cierre_anterior'],
        details['cierre_actual'],
        details['vencimiento'],
        f"$ {details['pago_minimo']:,.2f}".replace(",", "X").replace(".", ",").replace("X", "."),
        f"$ {details['pago_total_ars']:,.2f}".replace(",", "X").replace(".", ",").replace("X", "."),
        f"U$S {details['pago_total_usd']:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    ]
    
    summary_data = [
        [Paragraph(f"<b>{h}</b>", ParagraphStyle('SH', fontName='Helvetica-Bold', fontSize=7, textColor=colors.HexColor('#666666'), alignment=1)) for h in summary_headers],
        [Paragraph(f"<b>{v}</b>" if i >= 3 else v, ParagraphStyle('SV', fontName='Helvetica-Bold' if i >= 3 else 'Helvetica', fontSize=9, textColor=colors.HexColor(primary_color) if i >= 3 else colors.black, alignment=1)) for i, v in enumerate(summary_values)]
    ]
    
    summary_table = Table(summary_data, colWidths=[89, 89, 89, 92, 88, 88])
    summary_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#F5F5F5')),
        ('BACKGROUND', (0,1), (-1,-1), colors.HexColor('#FFFFFF')),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#DDDDDD')),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('TOPPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(summary_table)
    story.append(Spacer(1, 15))
    
    # 3. Limits Table
    limits_headers = ["LÍMITE DE COMPRA", "LÍMITE EN CUOTAS", "LÍMITE DE FINANCIACIÓN", "LÍMITE DE ADELANTO"]
    limits_values = [
        f"$ {details['limite_compra']:,.2f}".replace(",", "X").replace(".", ",").replace("X", "."),
        f"$ {details['limite_cuotas']:,.2f}".replace(",", "X").replace(".", ",").replace("X", "."),
        f"$ {details['limite_finan']:,.2f}".replace(",", "X").replace(".", ",").replace("X", "."),
        f"$ {details['limite_adelanto']:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    ]
    limits_data = [
        [Paragraph(f"<b>{lh}</b>", ParagraphStyle('LH', fontName='Helvetica-Bold', fontSize=7, textColor=colors.HexColor('#555555'))) for lh in limits_headers],
        [Paragraph(lv, cell_style) for lv in limits_values]
    ]
    limits_table = Table(limits_data, colWidths=[133, 134, 134, 134])
    limits_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#FAFAFA')),
        ('LINEBELOW', (0,0), (-1,0), 1, colors.HexColor('#CCCCCC')),
        ('LINEBELOW', (0,1), (-1,-1), 1, colors.HexColor('#E5E5E5')),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(limits_table)
    story.append(Spacer(1, 20))
    
    # 4. Details of Transactions Header
    story.append(Paragraph("<b>DETALLE DE TRANSACCIONES / CONSUMOS</b>", subtitle_style))
    
    # 5. Transactions Table
    tx_headers = ["FECHA", "CONCEPTO / COMERCIO / DETALLE", "MONTO PESOS ($)", "MONTO DÓLARES (U$S)"]
    tx_rows = []
    tx_rows.append([Paragraph(f"<b>{th}</b>", ParagraphStyle('TH', fontName='Helvetica-Bold', fontSize=8, textColor=colors.white)) for th in tx_headers])
    
    for tx in transactions:
        fecha = Paragraph(tx[0], cell_style)
        concepto = Paragraph(tx[1], cell_style)
        
        monto_ars = tx[2]
        monto_usd = tx[3]
        
        m_ars_str = ""
        if monto_ars is not None:
            if monto_ars < 0:
                m_ars_str = f"- $ {abs(monto_ars):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
            else:
                m_ars_str = f"$ {monto_ars:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
                
        m_usd_str = ""
        if monto_usd is not None:
            if monto_usd < 0:
                m_usd_str = f"- U$S {abs(monto_usd):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
            else:
                m_usd_str = f"U$S {monto_usd:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
                
        tx_rows.append([
            fecha,
            concepto,
            Paragraph(m_ars_str, cell_right),
            Paragraph(m_usd_str, cell_right)
        ])
        
    # Totals Row
    total_ars_formatted = f"$ {details['pago_total_ars']:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    total_usd_formatted = f"U$S {details['pago_total_usd']:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    
    tx_rows.append([
        Paragraph("", cell_style),
        Paragraph("<b>SALDO DE LA LIQUIDACIÓN ACTUAL</b>", cell_bold),
        Paragraph(f"<b>{total_ars_formatted}</b>", cell_right_bold),
        Paragraph(f"<b>{total_usd_formatted}</b>", cell_right_bold)
    ])
    
    tx_table = Table(tx_rows, colWidths=[65, 270, 100, 100])
    tx_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor(primary_color)),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('ROWBACKGROUNDS', (0,1), (-1,-2), [colors.HexColor('#FFFFFF'), colors.HexColor('#F9F9F9')]),
        ('LINEBELOW', (0,1), (-1,-2), 0.5, colors.HexColor('#EEEEEE')),
        ('BACKGROUND', (0,-1), (-1,-1), colors.HexColor('#ECEFF1')),
        ('LINEABOVE', (0,-1), (-1,-1), 1.5, colors.HexColor(primary_color)),
        ('LINEBELOW', (0,-1), (-1,-1), 1.5, colors.HexColor(primary_color)),
    ]))
    story.append(tx_table)
    story.append(Spacer(1, 25))
    
    # 6. Legal & Footer
    footer_text = (
        "<b>INFORMACIÓN IMPORTANTE PARA EL USUARIO:</b><br/>"
        "El vencimiento opera el día indicado. En caso de disconformidad con los cargos detallados, dispone de un plazo de "
        "treinta (30) días a partir de la fecha de recepción del presente resumen para efectuar el correspondiente reclamo (Art. 26 Ley 25.065). "
        "Los consumos en moneda extranjera pueden ser abonados en dólares estadounidenses o en pesos argentinos al tipo de cambio vendedor del "
        "Banco Nación del día anterior al pago, más los impuestos correspondientes (Impuesto PAIS 8% o 30%, Percepciones de Ganancias/Bienes Personales)."
    )
    story.append(Paragraph(footer_text, ParagraphStyle('Footer', fontName='Helvetica', fontSize=7, leading=9, textColor=colors.HexColor('#666666'))))
    
    doc.build(story)


def create_bank_statement(filename, bank_name, primary_color, secondary_color, client_name, account_num, cbu, period, summary, transactions, cuit="30-71012345-9"):
    """
    Generates a bank account statement PDF (extracto bancario).
    """
    pdf_path = os.path.join(OUTPUT_DIR, filename)
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=A4,
        rightMargin=30,
        leftMargin=30,
        topMargin=30,
        bottomMargin=30
    )
    
    story = []
    styles = getSampleStyleSheet()
    
    header_label = ParagraphStyle(
        'BHLabel',
        fontName='Helvetica-Bold',
        fontSize=9,
        textColor=colors.white
    )
    
    header_val = ParagraphStyle(
        'BHVal',
        fontName='Helvetica',
        fontSize=9,
        textColor=colors.white
    )
    
    cell_style = ParagraphStyle(
        'BCell',
        fontName='Helvetica',
        fontSize=8,
        leading=10
    )
    
    cell_bold = ParagraphStyle(
        'BCellBold',
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10
    )
    
    cell_right = ParagraphStyle(
        'BCellRight',
        fontName='Helvetica',
        fontSize=8,
        alignment=2
    )
    
    cell_right_bold = ParagraphStyle(
        'BCellRightBold',
        fontName='Helvetica-Bold',
        fontSize=8,
        alignment=2
    )
    
    subtitle_style = ParagraphStyle(
        'BDocSubTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10,
        textColor=colors.HexColor('#555555'),
        spaceAfter=15
    )

    cbu_label = "CVU" if cbu.startswith("000") else "CBU"
    doc_type = "RESUMEN DE CUENTA DE PAGO" if cbu_label == "CVU" else "EXTRACTO DE CUENTA BANCARIA"

    # 1. Header Banner
    header_data = [
        [
            Paragraph(f"<b>{bank_name.upper()}</b>", header_label),
            Paragraph(f"<b>{doc_type}</b>", header_label)
        ],
        [
            Paragraph(f"<b>Titular:</b> {client_name}<br/><b>{cbu_label}:</b> {cbu}<br/><b>Dirección:</b> Av. Corrientes 350, CABA", header_val),
            Paragraph(f"<b>Nro. Cuenta:</b> {account_num}<br/><b>Período:</b> {period}<br/><b>CUIT:</b> {cuit}", header_val)
        ]
    ]
    
    header_table = Table(header_data, colWidths=[270, 265])
    header_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor(primary_color)),
        ('TEXTCOLOR', (0,0), (-1,-1), colors.white),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 12),
        ('RIGHTPADDING', (0,0), (-1,-1), 12),
        ('LINEBELOW', (0,0), (-1,0), 1, colors.HexColor(secondary_color)),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 15))
    
    # 2. Account Summary Table (Saldo Inicio, Creditos, Debitos, Saldo Cierre)
    sum_headers = ["SALDO DE INICIO", "TOTAL DEPÓSITOS (+)", "TOTAL DÉBITOS (-)", "SALDO AL CIERRE"]
    sum_values = [
        f"$ {summary['saldo_inicio']:,.2f}".replace(",", "X").replace(".", ",").replace("X", "."),
        f"$ {summary['total_depositos']:,.2f}".replace(",", "X").replace(".", ",").replace("X", "."),
        f"$ {summary['total_debitos']:,.2f}".replace(",", "X").replace(".", ",").replace("X", "."),
        f"$ {summary['saldo_cierre']:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    ]
    
    sum_data = [
        [Paragraph(f"<b>{sh}</b>", ParagraphStyle('BSH', fontName='Helvetica-Bold', fontSize=7, textColor=colors.HexColor('#666666'), alignment=1)) for sh in sum_headers],
        [Paragraph(f"<b>{sv}</b>" if i == 3 else sv, ParagraphStyle('BSV', fontName='Helvetica-Bold' if i == 3 else 'Helvetica', fontSize=9, textColor=colors.HexColor(primary_color) if i == 3 else colors.black, alignment=1)) for i, sv in enumerate(sum_values)]
    ]
    
    sum_table = Table(sum_data, colWidths=[133, 134, 134, 134])
    sum_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#F5F5F5')),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#DDDDDD')),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('TOPPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(sum_table)
    story.append(Spacer(1, 20))
    
    # 3. Ledger Header
    story.append(Paragraph("<b>DETALLE DE MOVIMIENTOS BANCARIOS</b>", subtitle_style))
    
    # 4. Ledger Table
    ledger_headers = ["FECHA", "CONCEPTO / DESCRIPCIÓN", "DÉBITO / RETIRO (-)", "CRÉDITO / DEPÓSITO (+)", "SALDO RESULTANTE"]
    ledger_rows = []
    ledger_rows.append([Paragraph(f"<b>{lh}</b>", ParagraphStyle('LHead', fontName='Helvetica-Bold', fontSize=8, textColor=colors.white)) for lh in ledger_headers])
    
    for tx in transactions:
        fecha = Paragraph(tx[0], cell_style)
        concepto = Paragraph(tx[1], cell_style)
        
        deb = tx[2]
        cred = tx[3]
        saldo = tx[4]
        
        deb_str = f"$ {deb:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".") if deb is not None else ""
        cred_str = f"$ {cred:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".") if cred is not None else ""
        saldo_str = f"$ {saldo:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
        
        ledger_rows.append([
            fecha,
            concepto,
            Paragraph(deb_str, cell_right),
            Paragraph(cred_str, cell_right),
            Paragraph(saldo_str, cell_right)
        ])
        
    # Final Total Row
    cierre_formatted = f"$ {summary['saldo_cierre']:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    ledger_rows.append([
        Paragraph("", cell_style),
        Paragraph("<b>SALDO AL CIERRE DEL PERÍODO</b>", cell_bold),
        Paragraph("", cell_style),
        Paragraph("", cell_style),
        Paragraph(f"<b>{cierre_formatted}</b>", cell_right_bold)
    ])
    
    ledger_table = Table(ledger_rows, colWidths=[55, 230, 80, 80, 90])
    ledger_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor(primary_color)),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('ROWBACKGROUNDS', (0,1), (-1,-2), [colors.white, colors.HexColor('#F9F9F9')]),
        ('LINEBELOW', (0,1), (-1,-2), 0.5, colors.HexColor('#EEEEEE')),
        ('BACKGROUND', (0,-1), (-1,-1), colors.HexColor('#ECEFF1')),
        ('LINEABOVE', (0,-1), (-1,-1), 1.5, colors.HexColor(primary_color)),
        ('LINEBELOW', (0,-1), (-1,-1), 1.5, colors.HexColor(primary_color)),
    ]))
    story.append(ledger_table)
    story.append(Spacer(1, 20))
    
    # 5. Regulatory Legal Footer
    footer_text = (
        "<b>GARANTÍA DE DEPÓSITOS Y RECLAMOS:</b><br/>"
        "Los depósitos en pesos y en moneda extranjera están garantizados por el Seguro de Garantía de los Depósitos "
        "conforme a la Ley 24.485, Decreto 540/95 y las normas del Banco Central de la República Argentina (BCRA). "
        "El cliente dispone de un plazo de treinta (30) días corridos desde la recepción de este resumen para presentar "
        "su disconformidad o impugnación de movimientos. Transcurrido dicho plazo, se considerará aceptado el saldo "
        "liquidado (Art. 73 de la Ley de Entidades Financieras)."
    )
    story.append(Paragraph(footer_text, ParagraphStyle('BFooter', fontName='Helvetica', fontSize=7, leading=9, textColor=colors.HexColor('#666666'))))
    
    doc.build(story)


# ----------------------------------------------------
# 1. Visa Galicia Credit Card Statement
# ----------------------------------------------------
visa_details = {
    'cierre_anterior': "10/05/2026",
    'cierre_actual': "11/06/2026",
    'vencimiento': "22/06/2026",
    'pago_minimo': 25600.00,
    'pago_total_ars': 345720.00,
    'pago_total_usd': 120.50,
    'limite_compra': 1500000.00,
    'limite_cuotas': 2000000.00,
    'limite_finan': 1000000.00,
    'limite_adelanto': 150000.00
}

visa_txs = [
    ["12/05", "MERCADOPAGO*ML COMPRAS", 12500.00, None],
    ["14/05", "JUMBO ALMAGRO SUC 23", 45230.00, None],
    ["18/05", "CABIFY ARGENTINA", 3400.00, None],
    ["25/05", "NETFLIX.COM EL SEGUNDO", None, 7.99],
    ["25/05", "DB.IVA SERV.DIGITAL 21% (NETFLIX)", 1637.95, None],
    ["25/05", "DB.IMP.PAIS DIGIT 8% (NETFLIX)", 623.98, None],
    ["25/05", "DB.PERC RG4815 DIG 30% (NETFLIX)", 2339.92, None],
    ["02/06", "SHELL HORNOS S.A.", 28000.00, None],
    ["04/06", "SUBSC. OPENAI CHATGPT", None, 20.00],
    ["04/06", "DB.IVA SERV.DIGITAL 21% (OPENAI)", 4094.00, None],
    ["04/06", "DB.IMP.PAIS DIGIT 8% (OPENAI)", 1560.00, None],
    ["04/06", "DB.PERC RG4815 DIG 30% (OPENAI)", 5850.00, None],
    ["05/06", "PAGO POR TRANSFERENCIA BANCO", -120000.00, None],
    ["08/06", "COOPERATIVA DE ELECTRICIDAD SECTOR A", 14500.00, None],
    ["10/06", "DESPEGAR VIAJES SA CUOTA 01/03", 95000.00, None],
    ["10/06", "AIRBNB BOOKING TRIP", None, 92.51],
    ["11/06", "IMPUESTO DE SELLOS PBA 1.2%", 4148.64, None],
    ["11/06", "CARGO MANTENIMIENTO RESUMEN", 2335.51, None],
]

create_card_statement(
    "resumen_visa_galicia.pdf",
    "Banco Galicia",
    "Visa",
    "#1A1F71", # Deep Visa Blue
    "#FF8F00", # Galicia Orange Accent
    "JUAN PEREZ",
    "4509-XXXX-XXXX-9876",
    visa_details,
    visa_txs
)


# ----------------------------------------------------
# 2. Mastercard Macro Credit Card Statement
# ----------------------------------------------------
master_details = {
    'cierre_anterior': "04/05/2026",
    'cierre_actual': "05/06/2026",
    'vencimiento': "16/06/2026",
    'pago_minimo': 18000.00,
    'pago_total_ars': 215900.00,
    'pago_total_usd': 45.00,
    'limite_compra': 900000.00,
    'limite_cuotas': 1200000.00,
    'limite_finan': 600000.00,
    'limite_adelanto': 90000.00
}

master_txs = [
    ["10/05", "PAGO MIS CUENTAS CLARO HOGAR", 8900.00, None],
    ["12/05", "COTO SUC 65 MONTE CASTRO", 38600.00, None],
    ["15/05", "RAPI PAGO SERVICIOS PUBLICOS", 15000.00, None],
    ["17/05", "SPOTIFY DE MULTI-CURRENCY", None, 5.00],
    ["17/05", "DB.IVA SERV.DIGITAL 21% (SPOTIFY)", 1024.00, None],
    ["17/05", "DB.IMP.PAIS DIGIT 8% (SPOTIFY)", 390.00, None],
    ["22/05", "AMAZON WEB SERVICES CLOUD", None, 40.00],
    ["22/05", "DB.IVA SERV.DIGITAL 21% (AWS)", 8192.00, None],
    ["22/05", "DB.IMP.PAIS DIGIT 8% (AWS)", 3120.00, None],
    ["22/05", "DB.PERC RG4815 DIG 30% (AWS)", 11700.00, None],
    ["28/05", "FARMACIA DR. AHORRO CAPITAL", 6400.00, None],
    ["03/06", "PAGO BANCO HOMEBANKING DEB.AUT", -150000.00, None],
    ["04/06", "FRÁVEGA S.A. COMPRA CUOTA 02/06", 45000.00, None],
    ["05/06", "IMPUESTO DE SELLOS CABA 1.2%", 2590.80, None],
    ["05/06", "SERVICIO DE COBERTURA ASISTENCIA", 1920.00, None],
]

create_card_statement(
    "resumen_mastercard_macro.pdf",
    "Banco Macro",
    "Mastercard",
    "#EB001B", # Mastercard Red
    "#F79E1B", # Mastercard Yellow/Orange Accent
    "MARIA INES GONZALEZ",
    "5412-XXXX-XXXX-4321",
    master_details,
    master_txs
)


# ----------------------------------------------------
# 3. Banco Santander Río Account Statement
# ----------------------------------------------------
santander_summary = {
    'saldo_inicio': 45200.00,
    'total_depositos': 780000.00,
    'total_debitos': 691780.00,
    'saldo_cierre': 133420.00
}

santander_txs = [
    ["05/05", "ACREDITACION DE HABERES S.A.", None, 750000.00, 795200.00],
    ["07/05", "DEB.INMEDIATO MERCADOPAGO PEREZ J", 35000.00, None, 760200.00],
    ["10/05", "TRANSF. BANCARIA ENVIADA A SOSA A", 120000.00, None, 640200.00],
    ["15/05", "COMPRA C/DEBITO COTO SUC 12 ALMAGRO", 42800.00, None, 597400.00],
    ["18/05", "PAGO TARJETA VISA AUTOMATICO GALICIA", 350000.00, None, 247400.00],
    ["20/05", "EXTRACCION EFECTIVO BANELCO SUC 101", 40000.00, None, 207400.00],
    ["22/05", "COMISION MANTENIMIENTO CUENTA DUO", 12500.00, None, 194900.00],
    ["22/05", "IVA COMISION REGIMEN GRAL 21%", 2625.00, None, 192275.00],
    ["25/05", "DEBITO SEGURO ASISTENCIA SANTANDER", 4500.00, None, 187775.00],
    ["30/05", "TRANSF. BANCARIA RECIBIDA GOMEZ J", None, 30000.00, 217775.00],
    ["31/05", "DEBITO RETENCION IMPUESTO SIRCREB", 4355.00, None, 213420.00],
    ["31/05", "IMP.DEB/CRED LEY 25413 OPERACIONES", 8000.00, None, 205420.00],
]

create_bank_statement(
    "resumen_cuenta_santander.pdf",
    "Banco Santander",
    "#EC0000", # Santander Red
    "#333333", # Dark Grey
    "CARLOS ALBERTO RODRIGUEZ",
    "123-456789/0",
    "0720123420000004567891",
    "01/05/2026 al 31/05/2026",
    santander_summary,
    santander_txs
)


# ----------------------------------------------------
# 4. Banco Galicia Account Statement
# ----------------------------------------------------
galicia_summary = {
    'saldo_inicio': 1250000.00,
    'total_depositos': 1350000.00,
    'total_debitos': 2300000.00,
    'saldo_cierre': 300000.00
}

galicia_txs = [
    ["04/05", "DEPÓSITO DE CHEQUE VALOR AL COBRO", None, 500000.00, 1750000.00],
    ["04/05", "IMPUESTO DEB/CRED LEY 25413 CREDITO", 3000.00, None, 1747000.00],
    ["08/05", "TRANSF. RECIBIDA PROV. NETWORKS SA", None, 850000.00, 2597000.00],
    ["12/05", "DEBITO PROVEEDORES DE MATERIALES SA", 950000.00, None, 1647000.00],
    ["15/05", "PAGO SUELDOS NOMINA QUINCENAL", 1200000.00, None, 447000.00],
    ["20/05", "GIRO EN DESCUBIERTO AUTORIZADO", 150000.00, None, 297000.00],
    ["20/05", "INTERESES POR ADELANTO DESCUBIERTO", 3800.00, None, 293200.00],
    ["20/05", "IVA SOBRE INTERESES REG GRAL 21%", 798.00, None, 292402.00],
    ["28/05", "TRANSF. RECIBIDA CLIENTE VIP REINTEGRO", None, 1100000.00, 1392402.00],
    ["31/05", "RENDIMIENTO DIARIO INVERSION GALICIA", None, 7598.00, 1400000.00],
]

create_bank_statement(
    "resumen_cuenta_galicia.pdf",
    "Banco Galicia",
    "#FF8F00", # Galicia Orange
    "#1A1F71", # Galicia Secondary Blue
    "ESTUDIO JURIDICO ASOCIADOS S.R.L.",
    "4000123-4 123-5",
    "0070123420000009876543",
    "01/05/2026 al 31/05/2026",
    galicia_summary,
    galicia_txs
)


# ----------------------------------------------------
# 5. BBVA Argentina Account Statement
# ----------------------------------------------------
bbva_summary = {
    'saldo_inicio': 18400.00,
    'total_depositos': 620000.00,
    'total_debitos': 304358.00,
    'saldo_cierre': 334042.00
}

bbva_txs = [
    ["05/05", "ACREDITACION DE HABERES MULTINACIONAL", None, 620000.00, 638400.00],
    ["10/05", "TRANSF. ENVIADA DEBIN MERCADOPAGO", 50000.00, None, 588400.00],
    ["14/05", "COMPRA DEBITO CARREFOUR EXPRESS 10", 32500.00, None, 555900.00],
    ["19/05", "PAGO TC MASTERCARD BANCO DEBITO AUT", 180000.00, None, 375900.00],
    ["22/05", "EXTRACCION CAJERO BANCO RED LINK", 30000.00, None, 345900.00],
    ["27/05", "COMISION SERVICIO DUO BBVA MENSUAL", 9800.00, None, 336100.00],
    ["27/05", "IVA COMISION REGIMEN INSC 21%", 2058.00, None, 334042.00],
]

create_bank_statement(
    "resumen_cuenta_bbva.pdf",
    "BBVA Argentina",
    "#004481", # BBVA Dark Blue
    "#FFFFFF", # White
    "LAURA BEATRIZ MARTINEZ",
    "302-123456/7",
    "0170123420000001234567",
    "01/05/2026 al 31/05/2026",
    bbva_summary,
    bbva_txs
)


# ----------------------------------------------------
# 6. Banco de la Provincia de Buenos Aires (BAPRO)
# ----------------------------------------------------
bapro_summary = {
    'saldo_inicio': 85000.00,
    'total_depositos': 410000.00,
    'total_debitos': 320000.00,
    'saldo_cierre': 175000.00
}

bapro_txs = [
    ["02/05", "ACREDITACION HABERES GCBA", None, 350000.00, 435000.00],
    ["05/05", "COMPRA DEBITO SUPER TIENDA", 24500.00, None, 410500.00],
    ["09/05", "TRANSFERENCIA ENVIADA CUENTA DNI", 15000.00, None, 395500.00],
    ["15/05", "TRANSFERENCIA RECIBIDA DNI PEREZ", None, 60000.00, 455500.00],
    ["18/05", "PAGO TARJETA VISA BAPRO DEB.AUT", 120000.00, None, 335500.00],
    ["22/05", "EXTRACCION CAJERO PROPIO BAPRO SUC 23", 5000.00, None, 330500.00],
    ["24/05", "PAGO DE SERVICIOS EDENOR SA", 8900.00, None, 321600.00],
    ["26/05", "TRANSFERENCIA ENVIADA PAGO ALQUILER", 145000.00, None, 176600.00],
    ["31/05", "DEBITO INTERESES E IVA S/DESCUBIERTO", 1600.00, None, 175000.00],
]

create_bank_statement(
    "resumen_cuenta_bapro.pdf",
    "Banco Provincia",
    "#007A33", # BAPRO Green
    "#FFFFFF", # White
    "RICARDO DANIEL GOMEZ",
    "501-876543/2",
    "0140123420000008765432", # CBU starts with 014
    "01/05/2026 al 31/05/2026",
    bapro_summary,
    bapro_txs,
    cuit="30-99900012-2"
)


# ----------------------------------------------------
# 7. Cencopay (Cencosud PSP/Wallet)
# ----------------------------------------------------
cencopay_summary = {
    'saldo_inicio': 12000.00,
    'total_depositos': 250000.00,
    'total_debitos': 212500.00,
    'saldo_cierre': 49500.00
}

cencopay_txs = [
    ["03/05", "CARGA DE SALDO VIA TRANSF CVU COELSA", None, 200000.00, 212000.00],
    ["05/05", "COMPRA JUMBO PALERMO C/APP CENCOPAY", 48900.00, None, 163100.00],
    ["05/05", "REINTEGRO EXCLUSIVO CENCOPAY JUMBO", None, 9780.00, 172880.00],
    ["12/05", "COMPRA EASY PORTAL PALERMO ACC", 64200.00, None, 108680.00],
    ["15/05", "PAGO DE SERVICIOS METROGAS C/APP", 12400.00, None, 96280.00],
    ["20/05", "CARGA DE SALDO TARJETA DEBITO MAESTRO", None, 40220.00, 136500.00],
    ["22/05", "COMPRA SUPERMERCADOS VEA ALMAGRO SUC", 37000.00, None, 99500.00],
    ["27/05", "TRANSFERENCIA A OTRA CVU GOMEZ LUCAS", 50000.00, None, 49500.00],
]

create_bank_statement(
    "resumen_cuenta_cencopay.pdf",
    "Cencopay",
    "#6DBF43", # Cencopay Green
    "#FFFFFF", # White
    "PATRICIA ELIZABETH DIAZ",
    "CVU-982347-1",
    "0000003100098234712345", # CVU starts with 000
    "01/05/2026 al 31/05/2026",
    cencopay_summary,
    cencopay_txs,
    cuit="30-68731043-4"
)

print("SUCCESS: Generated 7 bank and credit card statement PDFs in:", OUTPUT_DIR)
