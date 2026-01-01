class Solution {
    public int maxBalancedShipments(int[] nums) {
        int maxi=-1;
        int n=nums.length;
        int count=0;
        for(int i=0;i<n;i++){
            if(nums[i]>maxi){
                maxi=nums[i];
            }
            if(maxi!=-1){
                if(nums[i]<maxi){
                    count++;
                    maxi=-1;
                }
            }
        }
        return count;
    }
}
