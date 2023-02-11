// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/utils/Counters.sol";
pragma solidity 0.8.14;

contract MainContract {

    using Counters for Counters.Counter;
    Counters.Counter public currPostID;
    address  payable immutable public owner;
    Post[] public allPosts;

    mapping(address => User) public allUsers;
    mapping(bytes32 => mapping(address =>bool))roleMapping;
    mapping(address => mapping(uint  => bool)) viewedPosts;

    bytes32 constant ADMIN = keccak256(abi.encodePacked("ADMIN"));
    bytes32 constant COOWNER = keccak256(abi.encodePacked("COOWNER"));

    error UserAlreadyPresent();
    error UserNotPresent();
    error NotOwner();
    error NotTheRequiredRole();
    error NotEnoughFunds();
    error AlreadyLiked();
    error AlreadyDisLiked();

    struct User {
        address wallet;
        uint [] likedPosts;
        uint [] disLikedPosts;
        address[] subscribedUsers;
    }

    struct Post {
        address poster;
        uint id;
        uint upVotes;
        uint downVotes;
        uint views;
        string [] ipfsImages;
        string ipfsText;
        bool takenDown;
        
    }


    modifier onlyOwner {
        if(msg.sender != owner){
            revert NotOwner();
        }
        _;
    }

    modifier ownerOrCowner{
        if(!roleMapping[COOWNER][msg.sender] || msg.sender == owner){
            revert NotTheRequiredRole();
        }
        _;
    }

    modifier anyRole(){
        if(!roleMapping[COOWNER][msg.sender] || msg.sender != owner || !roleMapping[ADMIN][msg.sender]){
            revert NotTheRequiredRole();
        }
        _;
    }


    modifier userPresentCheck {
        if(allUsers[msg.sender].wallet != address(0)){
            revert UserAlreadyPresent();
        }
        _;
    }
    modifier userNotPresentCheck {
         if(allUsers[msg.sender].wallet == address(0)){
            revert UserNotPresent();
        }
        _;
    }

    modifier notAlreadyLiked(uint postID) {
        User memory user = allUsers[msg.sender];
        uint n  = user.likedPosts.length;
        for(uint i=0;i<n;++i){
            if(user.likedPosts[i] == postID){
                revert AlreadyLiked();
            }
        }
        _;

    }

    modifier notAlreadyDisLiked(uint postID) {
        User memory user = allUsers[msg.sender];
        uint n  = user.disLikedPosts.length;
        for(uint i=0;i<n;++i){
            if(user.disLikedPosts[i] == postID){
                revert AlreadyDisLiked();
            }
        }
        _;

    }

    constructor( ) payable {
        owner =payable(msg.sender);
    }

    function grantCoOwnerRole() public onlyOwner{
        roleMapping[COOWNER][msg.sender] = true;
    }

    function grantAdminRole() public ownerOrCowner {
        roleMapping[ADMIN][msg.sender] = true;
    }

    function createUser() public userPresentCheck{
        allUsers[msg.sender].wallet  = msg.sender;
    }

    function createPost(string[] memory _ipfsImages , string memory _ipfsText ) public userNotPresentCheck {
        allPosts.push(Post(msg.sender , currPostID.current() , 0 ,0 , 0 ,_ipfsImages , _ipfsText , false ));
        currPostID.increment();
    }
    function getUser() public view returns(User memory){
        return allUsers[msg.sender];
    }

    function getPost(uint index) public view returns(Post memory){
        return allPosts[index];
    }
    function deletePost(uint index) public {
        require(allPosts[index].poster == msg.sender , "You must be the owner of the Post");
        allPosts[index] = allPosts[allPosts.length - 1];
        allPosts.pop();
    }

    function getAllValidPosts() public view returns(Post [] memory){
        uint n  =allPosts.length;
        uint size=0;
        for(uint i=0;i<n;++i){
            if(!allPosts[i].takenDown)size++;
        }
        Post [] memory res = new Post[](n) ; 
        uint itr=0;
        for(uint i=0 ;i<n;++i){
            if(!allPosts[i].takenDown){
                res[itr] = allPosts[itr];
                itr++;
            }
        }
        return res;
    }

    function makePostInvalid(uint index) public anyRole{
        allPosts[index].takenDown = true;

    }

    function withdrawFunds(uint amount) ownerOrCowner external {
        if(address(this).balance < amount){
            revert NotEnoughFunds();
        }
        payable(msg.sender).call{value : amount}("");
    }

    function addView(uint _post ) external {
        viewedPosts[msg.sender][_post] = true;
        getPost(_post).views++;

    }

    function getAllViewedPostsByUser() external view returns(uint [] memory){
        uint count=0;
        for(uint i=0;i<currPostID.current();++i){
            if(!getPost(i).takenDown && viewedPosts[msg.sender][i]){
                count++;
            }
        }

        uint [] memory res = new uint[](count);
        uint itr =0;
        for(uint i=0;i<currPostID.current();++i){
            if(!getPost(i).takenDown && viewedPosts[msg.sender][i]){
                res[itr] = i;
            }
        }

        return res;
    }

    function likePost(uint postID) external userPresentCheck notAlreadyLiked(postID) {
        User storage user = allUsers[msg.sender];
        user.likedPosts.push(postID);
        getPost(postID).upVotes++;
    }

    function removeFromLiked(uint postID) public userPresentCheck {
        User storage user  = allUsers[msg.sender];
        uint n = user.likedPosts.length;
        uint ind =0;
        bool flag = false;
        for(uint i=0;i<n;i++){
            if(user.likedPosts[i] == postID){
                flag = true;
                ind = i;
            }
        }
        if(flag){
            user.likedPosts[ind]= user.likedPosts[n-1];
            user.likedPosts.pop();

        }


    }

    function disLikePost(uint postID) external  userPresentCheck notAlreadyDisLiked(postID){
        User storage user = allUsers[msg.sender];
        user.disLikedPosts.push(postID);
        getPost(postID).downVotes++;
        removeFromLiked(postID);

    }

    function removeFromDisLiked(uint postID) public userPresentCheck {
        User storage user  = allUsers[msg.sender];
        uint n = user.disLikedPosts.length;
        uint ind =0;
        bool flag = false;
        for(uint i=0;i<n;i++){
            if(user.disLikedPosts[i] == postID){
                flag = true;
                ind = i;
            }
        }
        if(flag){
            user.disLikedPosts[ind]= user.disLikedPosts[n-1];
            user.disLikedPosts.pop();

        }


    }





}