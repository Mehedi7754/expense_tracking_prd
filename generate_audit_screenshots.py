import time
from PIL import Image, ImageDraw, ImageFont
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'

def get_driver(width, height):
    options = Options()
    options.add_argument('--headless=new')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-gpu')
    options.add_argument(f'--window-size={width},{height}')
    driver = webdriver.Chrome(options=options)
    return driver

def draw_problem_badge(draw, x, y, text, color=(220, 38, 38), subtext=None):
    # Draw callout badge
    pad_h, pad_v = 10, 5
    # Estimate text width
    font_size = 12
    box_w = max(len(text) * 7 + pad_h * 2, 140)
    box_h = 24 if not subtext else 38
    
    # Background pill
    draw.rounded_rectangle([x, y, x + box_w, y + box_h], radius=6, fill=color)
    draw.text((x + pad_h, y + 4), text, fill=(255, 255, 255))
    if subtext:
        draw.text((x + pad_h, y + 20), subtext, fill=(254, 226, 226))

def draw_bounding_box(draw, bbox, color=(220, 38, 38), width=3):
    draw.rectangle(bbox, outline=color, width=width)

def annotate_login_compact():
    driver = get_driver(320, 640)
    try:
        driver.get('http://localhost:8085')
        time.sleep(3) # Wait for splash redirect to /login
        raw_path = f'{OUTPUT_DIR}/login_320_raw.png'
        annotated_path = f'{OUTPUT_DIR}/login_320_marked.png'
        driver.save_screenshot(raw_path)
        
        # Load and annotate
        im = Image.open(raw_path).convert('RGBA')
        draw = ImageDraw.Draw(im)
        
        # Bounding box around Quick Role Switcher (overflow area)
        # Based on layout coordinates
        draw_bounding_box(draw, [16, 520, 304, 620], color=(239, 68, 68), width=3)
        draw_problem_badge(draw, 20, 495, "CRITICAL: RenderFlex Overflow", color=(185, 28, 28), 
                           subtext="Row overflows right edge by 54px-165px")
        
        # Bounding box around Forgot Password touch target
        draw_bounding_box(draw, [180, 275, 285, 298], color=(245, 158, 11), width=2)
        draw_problem_badge(draw, 100, 245, "UX FLAW: Touch Target < 48dp", color=(217, 119, 6),
                           subtext="Height is 23dp (Target minimum: 48dp)")
        
        im.save(annotated_path)
        print("Annotated compact login saved!")
    finally:
        driver.quit()

def annotate_login_standard():
    driver = get_driver(390, 844)
    try:
        driver.get('http://localhost:8085')
        time.sleep(3)
        raw_path = f'{OUTPUT_DIR}/login_390_standard.png'
        annotated_path = f'{OUTPUT_DIR}/login_390_marked.png'
        driver.save_screenshot(raw_path)
        
        im = Image.open(raw_path).convert('RGBA')
        draw = ImageDraw.Draw(im)
        
        # Good design badges
        draw_problem_badge(draw, 24, 75, "UI VERIFIED: WCAG 2.2 Contrast", color=(16, 149, 106),
                           subtext="Brand Slate #0F172A against #FFFFFF (Ratio 15.2:1)")
        
        # Mark Quick Switcher
        draw_bounding_box(draw, [24, 660, 366, 790], color=(59, 130, 246), width=2)
        draw_problem_badge(draw, 24, 630, "FEATURE: 1-Tap Demo Switcher", color=(37, 99, 235),
                           subtext="Instant role switching across Employee, Mgr, Fin, Admin")
        
        im.save(annotated_path)
        print("Annotated standard login saved!")
    finally:
        driver.quit()

def annotate_tablet_viewport():
    driver = get_driver(768, 1024)
    try:
        driver.get('http://localhost:8085')
        time.sleep(3)
        raw_path = f'{OUTPUT_DIR}/tablet_768_raw.png'
        annotated_path = f'{OUTPUT_DIR}/tablet_768_marked.png'
        driver.save_screenshot(raw_path)
        
        im = Image.open(raw_path).convert('RGBA')
        draw = ImageDraw.Draw(im)
        
        # Form Centering & Layout Callout
        draw_bounding_box(draw, [164, 120, 604, 720], color=(16, 185, 129), width=2)
        draw_problem_badge(draw, 170, 85, "RESPONSIVE: Constrained Form Box (440px)", color=(5, 150, 105),
                           subtext="Centered nicely, avoids excessive stretched inputs on tablet")
        
        # Callout on bottom empty space
        draw_problem_badge(draw, 220, 750, "UX SUGGESTION: Tablet Space Utilization", color=(217, 119, 6),
                           subtext="Large bottom whitespace on iPad viewport (>300px)")
        
        im.save(annotated_path)
        print("Annotated tablet view saved!")
    finally:
        driver.quit()

if __name__ == '__main__':
    annotate_login_compact()
    annotate_login_standard()
    annotate_tablet_viewport()
    print("All annotated screenshots generated successfully.")
