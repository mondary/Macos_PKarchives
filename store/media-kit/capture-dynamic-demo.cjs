const puppeteer = require('/tmp/pk-capture/node_modules/puppeteer-core');
const fs = require('fs');

(async () => {
  const output = '/tmp/pk-dynamic-frames';
  fs.mkdirSync(output, {recursive: true});
  const browser = await puppeteer.launch({
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
    args: ['--no-sandbox', '--disable-gpu'],
  });
  const page = await browser.newPage();
  await page.setViewport({width: 1200, height: 675, deviceScaleFactor: 1});
  await page.goto('http://127.0.0.1:4173/store/media-kit/dynamic-demo.html', {waitUntil: 'networkidle0'});
  for (let frame = 0; frame < 72; frame += 1) {
    await page.screenshot({path: `${output}/frame-${String(frame).padStart(3, '0')}.png`});
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  await browser.close();
})();
