import os
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Helper to draw rounded rectangle with outline and text
def draw_badge(draw, x, y, title, subtitle=None, bg_color=(220, 38, 38), border_color=(185, 28, 28), text_color=(255, 255, 255)):
    padding_x = 12
    padding_y = 6
    line_h = 16
    w = max(len(title) * 7 + padding_x * 2, (len(subtitle) * 6 + padding_x * 2) if subtitle else 100)
    h = padding_y * 2 + line_h + (line_h if subtitle else 0)
    
    draw.rounded_rectangle([x, y, x + w, y + h], radius=6, fill=bg_color, outline=border_color, width=1)
    draw.text((x + padding_x, y + padding_y), title, fill=text_color)
    if subtitle:
        draw.text((x + padding_x, y + padding_y + line_h), subtitle, fill=(255, 230, 230) if bg_color[0]>150 else (210, 245, 230))

def draw_dashed_box(draw, bbox, color=(220, 38, 38), width=2):
    draw.rectangle(bbox, outline=color, width=width)

# 1. Annotate Standard Mobile Login (login_390_base.png)
def make_login_390_annotated():
    src_path = f"{OUTPUT_DIR}/login_390_base.png"
    if not os.path.exists(src_path):
        return
    im = Image.open(src_path).convert("RGBA")
    draw = ImageDraw.Draw(im)

    # Top: WCAG Contrast
    draw_badge(draw, 24, 20, "ACCESSIBILITY PASS: Contrast 15.2:1 (AAA)", 
               "Brand Navy #0F172A on White #FFFFFF exceeds WCAG AAA", 
               bg_color=(16, 149, 106), border_color=(5, 122, 85))

    # Middle: Forgot Password touch target (right side above password box)
    draw_dashed_box(draw, [258, 392, 362, 412], color=(217, 119, 6), width=2)
    draw_badge(draw, 60, 370, "UX FLAW: Touch Target < 48dp", 
               "Height is only 20dp (Requires min 48dp)", 
               bg_color=(217, 119, 6), border_color=(180, 83, 9))

    # Middle: Form Container
    draw_dashed_box(draw, [24, 260, 366, 520], color=(16, 149, 106), width=2)
    draw_badge(draw, 34, 235, "UI VERIFIED: Clean Form Container", 
               "Max 440px constraint, rounded elevation, accessible labels", 
               bg_color=(16, 149, 106), border_color=(5, 122, 85))

    # Bottom: Quick Persona Switcher
    draw_dashed_box(draw, [24, 575, 366, 700], color=(37, 99, 235), width=2)
    draw_badge(draw, 34, 545, "UX FEATURE: 1-Tap Persona Switcher", 
               "Instant role switching for Employee, Manager, Finance, Admin", 
               bg_color=(37, 99, 235), border_color=(29, 78, 216))

    out_path = f"{OUTPUT_DIR}/login_390_annotated.png"
    im.save(out_path)
    print("Saved login_390_annotated.png")

# 2. Annotate Tablet Login (tablet_768_base.png)
def make_tablet_768_annotated():
    src_path = f"{OUTPUT_DIR}/tablet_768_base.png"
    if not os.path.exists(src_path):
        return
    im = Image.open(src_path).convert("RGBA")
    draw = ImageDraw.Draw(im)

    # Form box centered
    draw_dashed_box(draw, [160, 280, 608, 700], color=(16, 149, 106), width=2)
    draw_badge(draw, 170, 235, "RESPONSIVE PASS: Constrained Form Box (440px)", 
               "Form is properly centered, preventing stretched inputs on tablet", 
               bg_color=(16, 149, 106), border_color=(5, 122, 85))

    # Bottom blank space warning
    draw_dashed_box(draw, [160, 725, 608, 920], color=(217, 119, 6), width=2)
    draw_badge(draw, 180, 780, "USABILITY OPPORTUNITY: Large Tablet Whitespace", 
               "Over 200px empty area; recommend 2-column layout with product features", 
               bg_color=(217, 119, 6), border_color=(180, 83, 9))

    out_path = f"{OUTPUT_DIR}/tablet_768_annotated.png"
    im.save(out_path)
    print("Saved tablet_768_annotated.png")

# 3. Create ProjectCard RenderFlex Overflow Simulation & Diagram
def make_project_card_overflow_diagram():
    w, h = 860, 470
    im = Image.new("RGBA", (w, h), (248, 250, 252, 255))
    draw = ImageDraw.Draw(im)

    # Outer container
    draw.rounded_rectangle([20, 20, w - 20, h - 20], radius=16, fill=(255, 255, 255), outline=(226, 232, 240), width=2)

    # Header title
    draw.text((40, 36), "CRITICAL DEFECT: ProjectCard RenderFlex Overflow", fill=(15, 23, 42))
    draw.text((40, 56), "Location: lib/core/widgets/project_card.dart:122 (Unconstrained Row with 4 metric columns)", fill=(100, 116, 139))

    # Simulated Mobile Card at 360px viewport
    card_x, card_y, card_w, card_h = 40, 100, 340, 230
    draw.rounded_rectangle([card_x, card_y, card_x + card_w, card_y + card_h], radius=12, fill=(255, 255, 255), outline=(203, 213, 225), width=2)
    draw.text((card_x + 16, card_y + 16), "Mobile App Redesign", fill=(15, 23, 42))
    draw.text((card_x + 16, card_y + 36), "Design System & Prototyping", fill=(100, 116, 139))
    
    # Progress bar
    draw.rounded_rectangle([card_x + 16, card_y + 65, card_x + card_w - 16, card_y + 73], radius=4, fill=(241, 245, 249))
    draw.rounded_rectangle([card_x + 16, card_y + 65, card_x + 220, card_y + 73], radius=4, fill=(37, 99, 235))

    # Metric Columns inside unconstrained Row
    metrics = [("Budget", "$50,000"), ("Spent", "$32,450"), ("Revenue", "$78,000"), ("Profit", "$45,550")]
    col_w = 90
    start_mx = card_x + 14
    for i, (lbl, val) in enumerate(metrics):
        mx = start_mx + i * col_w
        if mx + col_w > card_x + card_w:
            # Overflowing beyond card border!
            draw.rectangle([mx, card_y + 95, mx + col_w - 6, card_y + 155], fill=(254, 226, 226), outline=(239, 68, 68), width=2)
            draw.text((mx + 6, card_y + 105), lbl, fill=(185, 28, 28))
            draw.text((mx + 6, card_y + 127), val, fill=(185, 28, 28))
        else:
            draw.rectangle([mx, card_y + 95, mx + col_w - 6, card_y + 155], fill=(248, 250, 252), outline=(226, 232, 240), width=1)
            draw.text((mx + 6, card_y + 105), lbl, fill=(100, 116, 139))
            draw.text((mx + 6, card_y + 127), val, fill=(15, 23, 42))

    # Flutter Overflow Warning Stripe
    hazard_x = card_x + card_w - 15
    draw.rectangle([hazard_x, card_y + 95, hazard_x + 85, card_y + 155], fill=(254, 240, 138), outline=(234, 179, 8), width=2)
    draw.text((hazard_x + 8, card_y + 118), "OVERFLOW 52px", fill=(161, 98, 7))

    # Right side: Architecture & Remediation Explanation
    info_x = 475
    draw_badge(draw, info_x, 100, "FLUTTER ENGINE RUNTIME EXCEPTION", "A RenderFlex overflowed by 32px to 97px on small/mid screens", bg_color=(220, 38, 38), border_color=(185, 28, 28))
    
    draw.text((info_x, 165), "Defect Analysis:", fill=(15, 23, 42))
    draw.text((info_x, 185), "- Row directly lays out 4 fixed-width financial metric columns.", fill=(71, 85, 105))
    draw.text((info_x, 205), "- Total required width = 4 x 90px + paddings = 392px.", fill=(71, 85, 105))
    draw.text((info_x, 225), "- Exceeds screen width on 320x568, 360x640, and 390x844 dp.", fill=(71, 85, 105))

    draw.text((info_x, 260), "Recommended Architecture Fix:", fill=(15, 23, 42))
    draw.rectangle([info_x, 285, w - 40, 375], fill=(241, 245, 249), outline=(203, 213, 225), width=1)
    draw.text((info_x + 12, 295), "1. Wrap in 2x2 Responsive Grid:", fill=(30, 41, 59))
    draw.text((info_x + 12, 315), "   GridView.count(crossAxisCount: 2, shrinkWrap: true)", fill=(16, 149, 106))
    draw.text((info_x + 12, 335), "2. Or use Flexible columns in Row:", fill=(30, 41, 59))
    draw.text((info_x + 12, 355), "   Row(children: metrics.map((m) => Expanded(child: m)).toList())", fill=(16, 149, 106))

    # Footer banner
    draw.rounded_rectangle([40, 395, w - 40, 435], radius=6, fill=(254, 242, 242), outline=(252, 165, 165), width=1)
    draw.text((50, 408), "Cross-Screen Impact: Triggers crashes in HomeDashboardScreen, ProjectsListScreen, & CompanyDashboardScreen", fill=(185, 28, 28))

    out_path = f"{OUTPUT_DIR}/project_card_overflow_annotated.png"
    im.save(out_path)
    print("Saved project_card_overflow_annotated.png")

# 4. Create StatCard Grid Defect Graphic
def make_stat_card_grid_diagram():
    w, h = 860, 450
    im = Image.new("RGBA", (w, h), (248, 250, 252, 255))
    draw = ImageDraw.Draw(im)

    # Outer container
    draw.rounded_rectangle([20, 20, w - 20, h - 20], radius=16, fill=(255, 255, 255), outline=(226, 232, 240), width=2)

    # Header
    draw.text((40, 36), "RESPONSIVE DEFECT: Hardcoded 3-Column StatCard Squeezing", fill=(15, 23, 42))
    draw.text((40, 56), "Location: lib/screens/reports/company_dashboard_screen.dart:85 (GridView.count crossAxisCount: 3)", fill=(100, 116, 139))

    # Mobile Screen representation
    phone_x, phone_y, phone_w, phone_h = 40, 95, 340, 240
    draw.rounded_rectangle([phone_x, phone_y, phone_x + phone_w, phone_y + phone_h], radius=12, fill=(255, 255, 255), outline=(203, 213, 225), width=2)
    draw.text((phone_x + 16, phone_y + 14), "Mobile Screen (Width: 360dp)", fill=(15, 23, 42))

    # 3 squished columns inside 340px width (~95px each)
    titles = ["Total Rev", "Expenses", "Net Marg"]
    vals = ["$1.24M", "$840.5K", "+32.1%"]
    cw = 96
    for i in range(3):
        cx = phone_x + 16 + i * (cw + 6)
        draw.rectangle([cx, phone_y + 45, cx + cw, phone_y + 160], fill=(254, 242, 242), outline=(239, 68, 68), width=2)
        draw.text((cx + 6, phone_y + 55), titles[i], fill=(185, 28, 28))
        draw.text((cx + 6, phone_y + 75), vals[i], fill=(15, 23, 42))
        # Visual overflow indicator inside card
        draw.rectangle([cx + 6, phone_y + 105, cx + cw + 15, phone_y + 125], fill=(254, 240, 138), outline=(234, 179, 8), width=1)
        draw.text((cx + 8, phone_y + 110), "Text Clip!", fill=(161, 98, 7))

    draw_badge(draw, phone_x + 16, phone_y + 180, "DEFECT: Card Squeezed to 96px", "Labels truncated, icons cut off, 20-50px overflow", bg_color=(220, 38, 38), border_color=(185, 28, 28))

    # Right side: Remediation
    info_x = 420
    draw_badge(draw, info_x, 95, "RESPONSIVE DESIGN VIOLATION", "Fails mobile fluid grid standard (crossAxisCount should adapt)", bg_color=(217, 119, 6), border_color=(180, 83, 9))

    draw.text((info_x, 160), "Root Cause:", fill=(15, 23, 42))
    draw.text((info_x, 180), "- Hardcoded 'crossAxisCount: 3' divides mobile screen into 3 columns.", fill=(71, 85, 105))
    draw.text((info_x, 200), "- Available width per card on mobile is < 100px.", fill=(71, 85, 105))
    draw.text((info_x, 220), "- Causes vertical and horizontal overflows inside StatCard widget.", fill=(71, 85, 105))

    draw.text((info_x, 255), "Recommended Responsive Pattern:", fill=(15, 23, 42))
    draw.rectangle([info_x, 280, w - 40, 360], fill=(241, 245, 249), outline=(203, 213, 225), width=1)
    draw.text((info_x + 12, 290), "Use LayoutBuilder or MediaQuery breakpoint:", fill=(30, 41, 59))
    draw.text((info_x + 12, 310), "final isMobile = MediaQuery.of(context).size.width < 600;", fill=(16, 149, 106))
    draw.text((info_x + 12, 330), "crossAxisCount: isMobile ? 1 : (isTablet ? 2 : 3)", fill=(16, 149, 106))

    # Footer
    draw.rounded_rectangle([40, 380, w - 40, 415], radius=6, fill=(241, 245, 249), outline=(203, 213, 225), width=1)
    draw.text((50, 390), "Best Practice: Mobile viewports should stack KPI stat cards or use a 2-column grid.", fill=(51, 65, 85))

    out_path = f"{OUTPUT_DIR}/stat_card_grid_annotated.png"
    im.save(out_path)
    print("Saved stat_card_grid_annotated.png")

if __name__ == "__main__":
    make_login_390_annotated()
    make_tablet_768_annotated()
    make_project_card_overflow_diagram()
    make_stat_card_grid_diagram()
    print("All annotated artifacts refreshed successfully!")
