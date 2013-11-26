$(document).ready(function(){
  var length = $("div[class*='star_rating']").length;
  for ( var i = 0; i < length; i++ ){
    var rating = $("input#rating_" + i).attr('value');
    $("div#star_" + i).raty({ readOnly: true, score: rating, number: 5 });
  }
});