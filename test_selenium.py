from selenium import webdriver
from selenium.webdriver.chrome.options import Options
import time

opts = Options()
opts.add_argument('--headless=new')
opts.add_argument('--no-sandbox')
opts.add_argument('--enable-unsafe-swiftshader')
opts.add_argument('--window-size=390,844')

driver = webdriver.Chrome(options=opts)
driver.get('http://localhost:8085/#/home')
time.sleep(5)
driver.save_screenshot('test_selenium_home.png')
print("Captured test_selenium_home.png, size:", len(open('test_selenium_home.png', 'rb').read()))
driver.quit()
