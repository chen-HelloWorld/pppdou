// Generates varied, deterministic charts for preview algorithm regression.
const fs = await import('node:fs/promises');
const os = await import('node:os');
const path = await import('node:path');

const colors = {
  A5: '#FFE44B',
  F6: '#913635',
  H7: '#010101',
  C23: '#C8E2F9',
};

function chart({name, columns, rows, pitch, majorEvery, background, touchEdge}) {
  const width = columns * pitch;
  const height = rows * pitch;
  const pieces = [`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">`, `<rect width="100%" height="100%" fill="${background}"/>`];
  for (let column = 0; column <= columns; column++) {
    const major = column % majorEvery === 0;
    pieces.push(`<path d="M${column * pitch} 0V${height}" stroke="${major ? '#97a8b4' : '#d5e0e5'}" stroke-width="${major ? 1.4 : .55}"/>`);
  }
  for (let row = 0; row <= rows; row++) {
    const major = row % majorEvery === 0;
    pieces.push(`<path d="M0 ${row * pitch}H${width}" stroke="${major ? '#97a8b4' : '#d5e0e5'}" stroke-width="${major ? 1.4 : .55}"/>`);
  }
  for (let row = 0; row < rows; row++) for (let column = 0; column < columns; column++) {
    const centerX = column - columns / 2, centerY = row - rows / 2;
    const inShape = centerX * centerX / (columns * columns * .12) + centerY * centerY / (rows * rows * .13) < 1 || touchEdge && row > rows * .43 && row < rows * .57 && column < 5;
    if (!inShape) continue;
    const id = row < rows * .30 ? 'F6' : column < columns * .43 ? 'A5' : column > columns * .58 ? 'C23' : 'H7';
    const x = column * pitch, y = row * pitch, fill = colors[id], lightText = id === 'F6' || id === 'H7';
    pieces.push(`<rect x="${x + .8}" y="${y + .8}" width="${pitch - 1.6}" height="${pitch - 1.6}" rx="${pitch * .08}" fill="${fill}"/>`);
    pieces.push(`<text x="${x + pitch / 2}" y="${y + pitch * .58}" text-anchor="middle" font-family="Arial" font-weight="700" font-size="${Math.max(5, pitch * .34)}" fill="${lightText ? '#fff' : '#303541'}">${id}</text>`);
  }
  pieces.push('</svg>');
  return {name, source: pieces.join('')};
}

const fixtures = [
  chart({name: 'grid-major-5.svg', columns: 29, rows: 29, pitch: 18, majorEvery: 5, background: '#f7fafb', touchEdge: false}),
  chart({name: 'grid-major-10-colored-bg.svg', columns: 40, rows: 34, pitch: 14, majorEvery: 10, background: '#e7f1ed', touchEdge: true}),
];
const directory = path.join(os.tmpdir(), 'pindou-regression-fixtures');
await fs.mkdir(directory, {recursive: true});
for (const fixture of fixtures) await fs.writeFile(path.join(directory, fixture.name), fixture.source);
console.log(fixtures.map((fixture) => path.join(directory, fixture.name)).join('\n'));
