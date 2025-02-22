import beads.*;

AudioContext ac;
SamplePlayer modulator;
BiquadFilter[] modulatorFilters, carrierFilters;
ShortFrameSegmenter[] sfs; 
Power[] powers; 
Gain[] carrierGains; 
Gain masterGain; 
WavePlayer carrier; 
int numBuckets = 16;
float minFreq = 40, maxFreq = 5000;

void setup() {
  size(800, 400);
  ac = new AudioContext();

  try {
    Sample sample = new Sample(dataPath("poem.wav"));
    modulator = new SamplePlayer(ac, sample);
    modulator.setLoopType(SamplePlayer.LoopType.LOOP_FORWARDS);
  } catch (Exception e) {
    println("Problem loading sample: poem.wav");
    e.printStackTrace();
    exit();
  }

  modulatorFilters = new BiquadFilter[numBuckets];
  carrierFilters = new BiquadFilter[numBuckets];
  sfs = new ShortFrameSegmenter[numBuckets];
  powers = new Power[numBuckets];
  carrierGains = new Gain[numBuckets];

  carrier = new WavePlayer(ac, 200, Buffer.SQUARE);

  float baseFreq = (float) Math.pow(maxFreq / minFreq, 1.0 / (numBuckets - 1));
  float baseChannel = log(minFreq) / log(baseFreq);
  float qValue = 0.0; 
  
  float freq0 = 0.0, freq1 = 0.0; 
  float qRatio = 0;
  
  for (int i = 0; i < numBuckets; i++) {
    
    float freq = (float) Math.pow(baseFreq, baseChannel + i);

    if (i == 0) {
        freq0 = freq;
        qRatio = qValue;
    } else {
        freq1 = freq;
        float crossover = freq0 + (freq1 - freq0)/2.0;
        qRatio = crossover / ((freq1 - freq0) / 2.0);
    }
    
    qRatio = constrain(qRatio, 1, 2);
    
    modulatorFilters[i] = new BiquadFilter(ac, BiquadFilter.BP_SKIRT, freq, qRatio);
    modulatorFilters[i].addInput(modulator);

    sfs[i] = new ShortFrameSegmenter(ac);
    sfs[i].addInput(modulatorFilters[i]);
    powers[i] = new Power();
    sfs[i].addListener(powers[i]);
    ac.out.addDependent(sfs[i]);

    carrierFilters[i] = new BiquadFilter(ac, BiquadFilter.BP_SKIRT, freq, 2);
    carrierFilters[i].addInput(carrier);

    carrierGains[i] = new Gain(ac, 1);
    carrierGains[i].addInput(carrierFilters[i]);
  }

  masterGain = new Gain(ac, numBuckets, 0.5);
  for (int i = 0; i < numBuckets; i++) {
    masterGain.addInput(carrierGains[i]);
  }
  ac.out.addInput(masterGain);

  ac.start();
}

void draw() {
  background(0);
  fill(255);

  for (int i = 0; i < numBuckets; i++) {
    if (powers[i].getFeatures() != null) {
      float p = powers[i].getFeatures();
      carrierGains[i].setGain(p);
      float barHeight = -p * height;
      rect(i * (width / numBuckets), height, width / numBuckets, barHeight);
    }
  }
}
