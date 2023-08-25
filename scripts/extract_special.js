#!/usr/bin/env node
const fs = require('fs');
const { execSync } = require('child_process');

function extractSpecial(input, marker) {
  const output = input.split(marker);
  return JSON.stringify(output);
}

const args = process.argv.slice(2);

if (args.length < 2 || args.length > 3) {
  console.log('Usage: node script.js <marker> [--error] [--file input_file]');
  process.exit(1);
}

const marker = args[0];
const isError = args.includes('--error');
let inputText = '';

if (args.includes('--file')) {
  const fileIndex = args.indexOf('--file');
  if (args.length > fileIndex + 1) {
    const inputFile = args[fileIndex + 1];
    try {
      inputText = fs.readFileSync(inputFile, 'utf8');
    } catch (err) {
      console.error('Error reading the input file:', err.message);
      process.exit(1);
    }
  } else {
    console.error('No input file provided.');
    process.exit(1);
  }
} else {
  const inputIndex = args.indexOf(marker) + 1;
  if (args.length > inputIndex) {
    inputText = args[inputIndex];
  } else {
    console.error('No input text provided.');
    process.exit(1);
  }
}

const processedText = extractSpecial(inputText, marker, isError);
console.log(processedText);
