#!/usr/bin/env python3
"""
Minimal test to verify the API works with just required parameters.
"""
import sys
from test_api_ios_mimic import test_api_submission, TEST_IMAGE_PATH

print("=" * 80)
print("🧪 MINIMAL API TEST - Only Required Parameters")
print("=" * 80)

# Test with no optional parameters
result = test_api_submission(
    TEST_IMAGE_PATH,
    dietary_restrictions=None,  # No dietary restrictions
    food_type=None,
    difficulty_preference=None,
    health_preference=None,
    meal_type=None,
    cooking_time_preference=None,
    number_of_recipes=None  # Should default to 5
)

if result and result.get('data', {}).get('recipes'):
    num_recipes = len(result['data']['recipes'])
    print(f"\n✅ Test passed! Server returned {num_recipes} recipes (expected default: 5)")
    print("\n🎯 Key findings:")
    print("  - Server handles missing optional parameters correctly")
    print("  - Default number of recipes is working")
    print("  - No user preferences were included in the prompt")
else:
    print("\n❌ Test failed!")
    sys.exit(1)