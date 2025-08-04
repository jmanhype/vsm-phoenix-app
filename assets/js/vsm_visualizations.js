// VSM Advanced Visualizations
// Real-time topology, variety flow, quantum states, and algedonic signals

import * as d3 from 'd3';

export const VSMVisualizations = {
  // Initialize all visualizations
  init() {
    this.initTopologyVisualization();
    this.initVarietyFlowHeatmap();
    this.initQuantumStateVisualizer();
    this.initAlgedonicPulseWaves();
    this.initRealTimeMetrics();
  },

  // VSM Topology Visualization with D3.js
  initTopologyVisualization() {
    const container = document.getElementById('vsm-topology');
    if (!container) return;

    const width = container.offsetWidth;
    const height = 600;

    const svg = d3.select('#vsm-topology')
      .append('svg')
      .attr('width', width)
      .attr('height', height)
      .attr('class', 'vsm-topology-svg');

    // Create force simulation
    this.simulation = d3.forceSimulation()
      .force('link', d3.forceLink().id(d => d.id).strength(d => d.strength))
      .force('charge', d3.forceManyBody().strength(-300))
      .force('center', d3.forceCenter(width / 2, height / 2))
      .force('y', d3.forceY(d => d.level * 100).strength(0.7));

    // Create arrow markers for directed edges
    svg.append('defs').selectAll('marker')
      .data(['command', 'feedback', 'control', 'algedonic'])
      .enter().append('marker')
      .attr('id', d => `arrow-${d}`)
      .attr('viewBox', '0 -5 10 10')
      .attr('refX', 20)
      .attr('refY', 0)
      .attr('markerWidth', 6)
      .attr('markerHeight', 6)
      .attr('orient', 'auto')
      .append('path')
      .attr('d', 'M0,-5L10,0L0,5')
      .attr('fill', d => this.getEdgeColor(d));

    // Container for zoom
    const g = svg.append('g').attr('class', 'topology-container');

    // Add zoom behavior
    const zoom = d3.zoom()
      .scaleExtent([0.5, 3])
      .on('zoom', (event) => {
        g.attr('transform', event.transform);
      });

    svg.call(zoom);

    this.topologyGroup = g;
  },

  // Update topology with new data
  updateTopology(data) {
    const g = this.topologyGroup;
    if (!g) return;

    // Update links
    const links = g.selectAll('.topology-link')
      .data(data.edges, d => `${d.source}-${d.target}`);

    links.enter()
      .append('line')
      .attr('class', 'topology-link')
      .attr('stroke', d => this.getEdgeColor(d.type))
      .attr('stroke-width', d => Math.sqrt(d.strength * 10))
      .attr('marker-end', d => `url(#arrow-${d.type})`)
      .merge(links)
      .transition()
      .duration(750)
      .attr('stroke-opacity', d => d.strength);

    links.exit().remove();

    // Update nodes
    const nodes = g.selectAll('.topology-node')
      .data(data.nodes, d => d.id);

    const nodeEnter = nodes.enter()
      .append('g')
      .attr('class', 'topology-node')
      .call(d3.drag()
        .on('start', this.dragstarted)
        .on('drag', this.dragged)
        .on('end', this.dragended));

    nodeEnter.append('circle')
      .attr('r', d => 20 + d.level * 5)
      .attr('fill', d => d.color)
      .attr('stroke', '#fff')
      .attr('stroke-width', 2);

    nodeEnter.append('text')
      .attr('dy', '.35em')
      .attr('text-anchor', 'middle')
      .attr('fill', 'white')
      .attr('font-size', '12px')
      .text(d => d.id.toUpperCase());

    // Add pulse animation for active nodes
    nodeEnter.append('circle')
      .attr('class', 'pulse-ring')
      .attr('r', d => 20 + d.level * 5)
      .attr('fill', 'none')
      .attr('stroke', d => d.color)
      .attr('stroke-width', 2)
      .attr('opacity', 0);

    nodes.exit().remove();

    // Update simulation
    if (this.simulation) {
      this.simulation.nodes(data.nodes);
      this.simulation.force('link').links(data.edges);
      this.simulation.alpha(0.3).restart();
    }
  },

  // Variety Flow Heatmap
  initVarietyFlowHeatmap() {
    const container = document.getElementById('variety-heatmap');
    if (!container) return;

    const margin = { top: 30, right: 30, bottom: 30, left: 60 };
    const width = container.offsetWidth - margin.left - margin.right;
    const height = 300 - margin.top - margin.bottom;

    const svg = d3.select('#variety-heatmap')
      .append('svg')
      .attr('width', width + margin.left + margin.right)
      .attr('height', height + margin.top + margin.bottom);

    const g = svg.append('g')
      .attr('transform', `translate(${margin.left},${margin.top})`);

    // Scales
    this.xScale = d3.scaleBand()
      .range([0, width])
      .domain(d3.range(24))
      .padding(0.01);

    this.yScale = d3.scaleBand()
      .range([height, 0])
      .domain(['S1', 'S2', 'S3', 'S4', 'S5'])
      .padding(0.01);

    // Color scale for variety intensity
    this.colorScale = d3.scaleSequential()
      .interpolator(d3.interpolateInferno)
      .domain([0, 100]);

    // Add axes
    g.append('g')
      .attr('class', 'x-axis')
      .attr('transform', `translate(0,${height})`)
      .call(d3.axisBottom(this.xScale).tickFormat(d => `${d}:00`));

    g.append('g')
      .attr('class', 'y-axis')
      .call(d3.axisLeft(this.yScale));

    this.heatmapGroup = g;
  },

  // Update heatmap with new variety flow data
  updateVarietyHeatmap(data) {
    const g = this.heatmapGroup;
    if (!g) return;

    const cells = g.selectAll('.heatmap-cell')
      .data(data, d => `${d.level}-${d.hour}`);

    cells.enter()
      .append('rect')
      .attr('class', 'heatmap-cell')
      .attr('x', d => this.xScale(d.hour))
      .attr('y', d => this.yScale(`S${d.level}`))
      .attr('width', this.xScale.bandwidth())
      .attr('height', this.yScale.bandwidth())
      .merge(cells)
      .transition()
      .duration(500)
      .attr('fill', d => this.colorScale(d.variety))
      .attr('opacity', d => d.efficiency);

    cells.exit().remove();

    // Add tooltip
    cells.on('mouseover', function(event, d) {
      const tooltip = d3.select('body').append('div')
        .attr('class', 'vsm-tooltip')
        .style('opacity', 0);

      tooltip.transition()
        .duration(200)
        .style('opacity', .9);

      tooltip.html(`
        <div>Level: S${d.level}</div>
        <div>Hour: ${d.hour}:00</div>
        <div>Variety: ${d.variety.toFixed(1)}</div>
        <div>Absorbed: ${d.absorbed.toFixed(1)}</div>
        <div>Efficiency: ${(d.efficiency * 100).toFixed(1)}%</div>
      `)
        .style('left', (event.pageX + 10) + 'px')
        .style('top', (event.pageY - 28) + 'px');
    })
    .on('mouseout', function() {
      d3.selectAll('.vsm-tooltip').remove();
    });
  },

  // Quantum State Visualizer
  initQuantumStateVisualizer() {
    const container = document.getElementById('quantum-states');
    if (!container) return;

    const canvas = document.createElement('canvas');
    canvas.width = container.offsetWidth;
    canvas.height = 400;
    canvas.id = 'quantum-canvas';
    container.appendChild(canvas);

    this.quantumCtx = canvas.getContext('2d');
    this.quantumCanvas = canvas;
    this.quantumAnimationFrame = null;
  },

  // Animate quantum superposition states
  animateQuantumStates(states) {
    if (!this.quantumCtx) return;

    const ctx = this.quantumCtx;
    const canvas = this.quantumCanvas;
    const width = canvas.width;
    const height = canvas.height;

    // Cancel previous animation
    if (this.quantumAnimationFrame) {
      cancelAnimationFrame(this.quantumAnimationFrame);
    }

    const animate = (timestamp) => {
      ctx.clearRect(0, 0, width, height);

      // Draw background grid
      ctx.strokeStyle = 'rgba(59, 130, 246, 0.1)';
      ctx.lineWidth = 1;
      for (let i = 0; i <= width; i += 40) {
        ctx.beginPath();
        ctx.moveTo(i, 0);
        ctx.lineTo(i, height);
        ctx.stroke();
      }
      for (let j = 0; j <= height; j += 40) {
        ctx.beginPath();
        ctx.moveTo(0, j);
        ctx.lineTo(width, j);
        ctx.stroke();
      }

      // Draw quantum states
      states.superpositions.forEach((state, index) => {
        const x = (index + 1) * width / (states.superpositions.length + 1);
        const y = height / 2;

        // Draw superposition visualization
        this.drawSuperposition(ctx, x, y, state, timestamp);

        // Draw entanglement lines
        if (state.entangled_with) {
          const targetIndex = states.superpositions.findIndex(s => s.id === state.entangled_with);
          if (targetIndex !== -1) {
            const targetX = (targetIndex + 1) * width / (states.superpositions.length + 1);
            this.drawEntanglement(ctx, x, y, targetX, height / 2, timestamp);
          }
        }
      });

      // Draw wave functions
      this.drawWaveFunctions(ctx, width, height, states.wave_functions, timestamp);

      // Continue animation
      this.quantumAnimationFrame = requestAnimationFrame(animate);
    };

    animate(0);
  },

  // Draw superposition state
  drawSuperposition(ctx, x, y, state, timestamp) {
    const radius = 30;
    const phase = state.phase + timestamp * 0.001;

    // Draw probability cloud
    const gradient = ctx.createRadialGradient(x, y, 0, x, y, radius * 2);
    gradient.addColorStop(0, `rgba(147, 51, 234, ${state.coherence})`);
    gradient.addColorStop(1, 'rgba(147, 51, 234, 0)');

    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(x, y, radius * 2, 0, 2 * Math.PI);
    ctx.fill();

    // Draw state vectors
    state.amplitudes.forEach((amp, i) => {
      const angle = phase + (i * Math.PI / state.amplitudes.length);
      const endX = x + Math.cos(angle) * radius * amp;
      const endY = y + Math.sin(angle) * radius * amp;

      ctx.strokeStyle = `rgba(139, 92, 246, ${amp})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(endX, endY);
      ctx.stroke();

      // Draw amplitude indicator
      ctx.fillStyle = '#8b5cf6';
      ctx.beginPath();
      ctx.arc(endX, endY, 4, 0, 2 * Math.PI);
      ctx.fill();
    });

    // Draw state label
    ctx.fillStyle = '#ffffff';
    ctx.font = '12px monospace';
    ctx.textAlign = 'center';
    ctx.fillText(state.id, x, y + radius + 20);
  },

  // Draw entanglement connection
  drawEntanglement(ctx, x1, y1, x2, y2, timestamp) {
    const phase = timestamp * 0.002;
    const midX = (x1 + x2) / 2;
    const midY = (y1 + y2) / 2;
    const controlY = midY - 50 * Math.sin(phase);

    ctx.strokeStyle = 'rgba(236, 72, 153, 0.6)';
    ctx.lineWidth = 2;
    ctx.setLineDash([5, 5]);
    ctx.lineDashOffset = -timestamp * 0.01;

    ctx.beginPath();
    ctx.moveTo(x1, y1);
    ctx.quadraticCurveTo(midX, controlY, x2, y2);
    ctx.stroke();

    ctx.setLineDash([]);
  },

  // Draw wave functions
  drawWaveFunctions(ctx, width, height, waveFunctions, timestamp) {
    if (!waveFunctions) return;

    ctx.strokeStyle = 'rgba(59, 130, 246, 0.3)';
    ctx.lineWidth = 1;

    waveFunctions.forEach((wf, index) => {
      const yOffset = height - 50 - (index * 30);
      ctx.beginPath();

      for (let x = 0; x < width; x++) {
        const t = x / width * 4 * Math.PI;
        const y = yOffset + wf.amplitude * 20 * Math.sin(t * wf.frequency + wf.phase + timestamp * 0.001);
        
        if (x === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }

      ctx.stroke();
    });
  },

  // Algedonic Pulse Wave Visualizer
  initAlgedonicPulseWaves() {
    const container = document.getElementById('algedonic-waves');
    if (!container) return;

    const canvas = document.createElement('canvas');
    canvas.width = container.offsetWidth;
    canvas.height = 200;
    canvas.id = 'algedonic-canvas';
    container.appendChild(canvas);

    this.algedonicCtx = canvas.getContext('2d');
    this.algedonicCanvas = canvas;
    this.pulseHistory = [];
  },

  // Animate algedonic pulses
  animateAlgedonicPulses(pulses) {
    if (!this.algedonicCtx) return;

    const ctx = this.algedonicCtx;
    const canvas = this.algedonicCanvas;
    const width = canvas.width;
    const height = canvas.height;

    // Add new pulses to history
    pulses.forEach(pulse => {
      this.pulseHistory.push({
        ...pulse,
        x: width,
        startTime: Date.now()
      });
    });

    // Keep only recent pulses
    this.pulseHistory = this.pulseHistory.filter(p => 
      Date.now() - p.startTime < 10000
    );

    const animate = () => {
      ctx.clearRect(0, 0, width, height);

      // Draw grid
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)';
      ctx.lineWidth = 1;
      for (let y = 0; y < height; y += 20) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(width, y);
        ctx.stroke();
      }

      // Draw center line
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.2)';
      ctx.beginPath();
      ctx.moveTo(0, height / 2);
      ctx.lineTo(width, height / 2);
      ctx.stroke();

      // Update and draw pulses
      this.pulseHistory.forEach(pulse => {
        const age = (Date.now() - pulse.startTime) / 1000;
        pulse.x -= 2; // Move left

        const y = height / 2;
        const amplitude = pulse.intensity * 50 * Math.exp(-age * 0.3);
        const frequency = 2 + pulse.intensity * 3;

        // Draw pulse wave
        ctx.strokeStyle = pulse.type === 'pain' 
          ? `rgba(239, 68, 68, ${1 - age / 10})`
          : `rgba(34, 197, 94, ${1 - age / 10})`;
        ctx.lineWidth = 2;

        ctx.beginPath();
        for (let x = Math.max(0, pulse.x - 100); x < Math.min(width, pulse.x); x++) {
          const t = (pulse.x - x) / 20;
          const waveY = y + amplitude * Math.sin(t * frequency) * Math.exp(-t * 0.1);
          
          if (x === Math.max(0, pulse.x - 100)) {
            ctx.moveTo(x, waveY);
          } else {
            ctx.lineTo(x, waveY);
          }
        }
        ctx.stroke();

        // Draw pulse origin marker
        if (pulse.x > 0 && pulse.x < width) {
          ctx.fillStyle = pulse.type === 'pain' ? '#ef4444' : '#22c55e';
          ctx.beginPath();
          ctx.arc(pulse.x, y, 5, 0, 2 * Math.PI);
          ctx.fill();
        }
      });

      requestAnimationFrame(animate);
    };

    animate();
  },

  // Real-time metrics sparklines
  initRealTimeMetrics() {
    const containers = document.querySelectorAll('.metric-sparkline');
    
    containers.forEach(container => {
      const metricType = container.dataset.metric;
      const svg = d3.select(container)
        .append('svg')
        .attr('width', 100)
        .attr('height', 30);

      const data = [];
      for (let i = 0; i < 20; i++) {
        data.push(Math.random());
      }

      const x = d3.scaleLinear()
        .domain([0, data.length - 1])
        .range([0, 100]);

      const y = d3.scaleLinear()
        .domain([0, 1])
        .range([30, 0]);

      const line = d3.line()
        .x((d, i) => x(i))
        .y(d => y(d))
        .curve(d3.curveMonotoneX);

      svg.append('path')
        .datum(data)
        .attr('class', 'sparkline')
        .attr('fill', 'none')
        .attr('stroke', '#3b82f6')
        .attr('stroke-width', 1.5)
        .attr('d', line);

      // Store for updates
      container.sparklineData = data;
      container.sparklinePath = svg.select('.sparkline');
      container.sparklineLine = line;
    });
  },

  // Update real-time metric sparklines
  updateSparklines(metrics) {
    const containers = document.querySelectorAll('.metric-sparkline');
    
    containers.forEach(container => {
      const metricType = container.dataset.metric;
      const value = metrics[metricType] || Math.random();

      if (container.sparklineData) {
        container.sparklineData.push(value);
        container.sparklineData.shift();

        container.sparklinePath
          .datum(container.sparklineData)
          .transition()
          .duration(100)
          .attr('d', container.sparklineLine);
      }
    });
  },

  // Helper functions
  getEdgeColor(type) {
    const colors = {
      command: '#9333ea',
      feedback: '#3b82f6',
      control: '#10b981',
      intelligence: '#06b6d4',
      coordination: '#eab308',
      algedonic: '#ef4444',
      audit: '#14b8a6',
      audit_request: '#6366f1'
    };
    return colors[type] || '#6b7280';
  },

  dragstarted(event, d) {
    if (!event.active) this.simulation.alphaTarget(0.3).restart();
    d.fx = d.x;
    d.fy = d.y;
  },

  dragged(event, d) {
    d.fx = event.x;
    d.fy = event.y;
  },

  dragended(event, d) {
    if (!event.active) this.simulation.alphaTarget(0);
    d.fx = null;
    d.fy = null;
  },

  // Clean up resources
  destroy() {
    if (this.quantumAnimationFrame) {
      cancelAnimationFrame(this.quantumAnimationFrame);
    }
    if (this.simulation) {
      this.simulation.stop();
    }
  }
};

// Export for Phoenix LiveView hooks
export default VSMVisualizations;