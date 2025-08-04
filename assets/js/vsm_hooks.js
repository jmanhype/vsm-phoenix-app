// Phoenix LiveView Hooks for VSM Visualizations
import VSMVisualizations from './vsm_visualizations';

export const VSMHooks = {
  VSMDashboard: {
    mounted() {
      console.log("VSM Dashboard mounted");
      
      // Initialize visualizations
      VSMVisualizations.init();
      
      // Set up Phoenix event handlers
      this.handleEvent("update_flow_viz", ({flows}) => {
        this.updateFlowVisualizations(flows);
      });
      
      this.handleEvent("update_quantum_viz", ({states}) => {
        VSMVisualizations.animateQuantumStates(states);
      });
      
      this.handleEvent("update_variety_heatmap", ({data}) => {
        VSMVisualizations.updateVarietyHeatmap(data);
      });
      
      this.handleEvent("update_topology", ({topology}) => {
        VSMVisualizations.updateTopology(topology);
      });
      
      this.handleEvent("algedonic_pulse", ({pulses}) => {
        VSMVisualizations.animateAlgedonicPulses(pulses);
      });
      
      this.handleEvent("update_metrics", ({metrics}) => {
        VSMVisualizations.updateSparklines(metrics);
      });
      
      this.handleEvent("toggle_viz", ({type}) => {
        this.toggleVisualization(type);
      });
      
      // Start with initial data if available
      if (this.el.dataset.topology) {
        const topology = JSON.parse(this.el.dataset.topology);
        VSMVisualizations.updateTopology(topology);
      }
      
      if (this.el.dataset.heatmap) {
        const heatmap = JSON.parse(this.el.dataset.heatmap);
        VSMVisualizations.updateVarietyHeatmap(heatmap);
      }
    },
    
    destroyed() {
      VSMVisualizations.destroy();
    },
    
    updateFlowVisualizations(flows) {
      // Update particle flows
      if (flows.particles) {
        this.animateParticles(flows.particles);
      }
      
      // Update flow intensities
      if (flows.intensities) {
        this.updateFlowIntensities(flows.intensities);
      }
      
      // Update algedonic pulses
      if (flows.pulses) {
        VSMVisualizations.animateAlgedonicPulses(flows.pulses);
      }
    },
    
    animateParticles(particles) {
      const container = document.getElementById('flow-particles');
      if (!container) return;
      
      // Clear existing particles
      container.innerHTML = '';
      
      particles.forEach(particle => {
        const div = document.createElement('div');
        div.className = `particle particle-${particle.type}`;
        div.style.left = `${particle.x}px`;
        div.style.top = `${particle.y}px`;
        div.style.animationDelay = `${Math.random() * 2}s`;
        
        container.appendChild(div);
        
        // Animate movement
        const animation = div.animate([
          { transform: `translate(0, 0)` },
          { transform: `translate(${particle.vx * 100}px, ${particle.vy * 100}px)` }
        ], {
          duration: 3000,
          iterations: Infinity,
          direction: 'alternate'
        });
      });
    },
    
    updateFlowIntensities(intensities) {
      // Update CSS variables for flow animations
      Object.entries(intensities).forEach(([key, value]) => {
        document.documentElement.style.setProperty(`--flow-${key}`, value);
      });
      
      // Update flow line opacities
      const flowLines = document.querySelectorAll('.flow-line');
      flowLines.forEach(line => {
        const flowType = line.dataset.flow;
        if (intensities[flowType]) {
          line.style.opacity = intensities[flowType];
          line.style.strokeWidth = Math.max(1, intensities[flowType] * 5) + 'px';
        }
      });
    },
    
    toggleVisualization(type) {
      const element = document.getElementById(`viz-${type}`);
      if (element) {
        element.classList.toggle('hidden');
        
        // Trigger resize for responsive visualizations
        if (!element.classList.contains('hidden')) {
          window.dispatchEvent(new Event('resize'));
        }
      }
    }
  },
  
  MetricSparkline: {
    mounted() {
      // Individual sparkline initialization
      const metric = this.el.dataset.metric;
      const value = parseFloat(this.el.dataset.value || 0);
      
      // Create mini sparkline
      this.createSparkline(metric, value);
    },
    
    updated() {
      const value = parseFloat(this.el.dataset.value || 0);
      this.updateSparkline(value);
    },
    
    createSparkline(metric, initialValue) {
      const canvas = document.createElement('canvas');
      canvas.width = 60;
      canvas.height = 20;
      canvas.className = 'inline-block ml-2';
      
      this.el.appendChild(canvas);
      
      const ctx = canvas.getContext('2d');
      this.sparklineData = Array(20).fill(initialValue);
      this.sparklineCtx = ctx;
      
      this.drawSparkline();
    },
    
    updateSparkline(value) {
      if (!this.sparklineData) return;
      
      this.sparklineData.push(value);
      this.sparklineData.shift();
      
      this.drawSparkline();
    },
    
    drawSparkline() {
      const ctx = this.sparklineCtx;
      const data = this.sparklineData;
      const width = ctx.canvas.width;
      const height = ctx.canvas.height;
      
      ctx.clearRect(0, 0, width, height);
      
      ctx.strokeStyle = '#3b82f6';
      ctx.lineWidth = 1;
      ctx.beginPath();
      
      data.forEach((value, index) => {
        const x = (index / (data.length - 1)) * width;
        const y = height - (value * height);
        
        if (index === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      });
      
      ctx.stroke();
    }
  },
  
  QuantumObserver: {
    mounted() {
      // Handle quantum state observations
      this.el.addEventListener('click', (e) => {
        const stateId = this.el.dataset.stateId;
        if (stateId) {
          this.pushEvent('observe_quantum_state', {state_id: stateId});
          
          // Visual feedback for observation
          this.el.classList.add('observing');
          setTimeout(() => {
            this.el.classList.remove('observing');
          }, 500);
        }
      });
    }
  },
  
  AlgedonicIndicator: {
    mounted() {
      this.animatePulse();
    },
    
    updated() {
      this.animatePulse();
    },
    
    animatePulse() {
      const intensity = parseFloat(this.el.dataset.intensity || 0);
      const type = this.el.dataset.type || 'neutral';
      
      // Create pulse animation
      const keyframes = [
        { transform: 'scale(1)', opacity: 1 },
        { transform: `scale(${1 + intensity * 0.5})`, opacity: 0.3 },
        { transform: 'scale(1)', opacity: 1 }
      ];
      
      const timing = {
        duration: 1000 / (1 + intensity * 2),
        iterations: Infinity,
        easing: 'ease-in-out'
      };
      
      if (this.animation) {
        this.animation.cancel();
      }
      
      this.animation = this.el.animate(keyframes, timing);
      
      // Update color based on type
      if (type === 'pain') {
        this.el.style.backgroundColor = '#ef4444';
      } else if (type === 'pleasure') {
        this.el.style.backgroundColor = '#22c55e';
      }
    },
    
    destroyed() {
      if (this.animation) {
        this.animation.cancel();
      }
    }
  }
};

export default VSMHooks;