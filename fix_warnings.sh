#!/bin/bash
# Fix all code warnings in VSM Phoenix

echo "🔧 Fixing code warnings in VSM Phoenix..."

# 1. Fix deprecated Logger.warn to Logger.warning
echo "Fixing Logger.warn deprecation warnings..."
find lib -name "*.ex" -exec sed -i '' 's/Logger\.warn(/Logger.warning(/g' {} \;

# 2. Fix elsif syntax errors (Elixir uses 'else if' or 'cond')
echo "Fixing elsif syntax errors..."
find lib -name "*.ex" -exec sed -i '' 's/elsif/else if/g' {} \;

# 3. Fix unused variable warnings by prefixing with underscore
echo "Fixing unused variables..."
# This is more complex and requires manual review, but here are common patterns:

# Fix in quantum_variety_analyzer.ex
sed -i '' 's/complexity_barrier/_complexity_barrier/g' lib/vsm_phoenix/system4/quantum_variety_analyzer.ex
sed -i '' 's/source1, source2/_source1, _source2/g' lib/vsm_phoenix/system4/quantum_variety_analyzer.ex
sed -i '' 's/tunneling_result = /_tunneling_result = /g' lib/vsm_phoenix/system4/quantum_variety_analyzer.ex

# Fix in fractal_architect.ex
sed -i '' 's/real_range = /_real_range = /g' lib/vsm_phoenix/meta_vsm/fractals/fractal_architect.ex
sed -i '' 's/imag_range = /_imag_range = /g' lib/vsm_phoenix/meta_vsm/fractals/fractal_architect.ex
sed -i '' 's/defp create_reconstruction_map(base_vsm)/defp create_reconstruction_map(_base_vsm)/g' lib/vsm_phoenix/meta_vsm/fractals/fractal_architect.ex

# 4. Group function clauses with same name together
echo "Note: Function clause grouping requires manual fixing in:"
echo "  - lib/vsm_phoenix/meta_vsm/fractals/fractal_architect.ex"

# 5. Remove unused module attributes
echo "Removing unused module attributes..."
sed -i '' '/@quantum_states \[:superposition/d' lib/vsm_phoenix/system4/quantum_variety_analyzer.ex
sed -i '' '/@collapse_threshold 0.85/d' lib/vsm_phoenix/system4/quantum_variety_analyzer.ex

# 6. Remove unused aliases
echo "Removing unused aliases..."
sed -i '' '/alias VsmPhoenix.System4.Intelligence$/d' lib/vsm_phoenix/system4/quantum_variety_analyzer.ex
sed -i '' '/alias VsmPhoenix.System4.LLMVarietySource$/d' lib/vsm_phoenix/system4/quantum_variety_analyzer.ex
sed -i '' '/alias VsmPhoenixWeb.AuthPipeline$/d' lib/vsm_phoenix_web/plugs/api_authentication.ex

# 7. Format all files
echo "Formatting all Elixir files..."
mix format

echo "✅ Warning fixes applied!"
echo ""
echo "Remaining manual fixes needed:"
echo "1. Group function clauses in fractal_architect.ex"
echo "2. Fix VsmPhoenix.Accounts.get_user/1 to use get_user!/1"
echo "3. Review any remaining warnings after compilation"

echo ""
echo "To see remaining warnings, run:"
echo "mix compile --warnings-as-errors"